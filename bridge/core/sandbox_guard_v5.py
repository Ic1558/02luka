#!/usr/bin/env python3
"""
SandboxGuard v5 — Security Boundary Enforcement

This module implements pre-write security checks defined in:
- GOVERNANCE_UNIFIED_v5.md (Section 6: Safety Invariants)
- AI_OP_001_v5.md (Section 5: SIP Requirements)
- PERSONA_MODEL_v5.md (Section 5: Forbidden Behaviors)

Author: 02luka System
Status: Implementation (Phase 3.3)
"""

import os
import re
import hashlib
from pathlib import Path
from typing import List, Tuple, Optional, Dict, Set
from dataclasses import dataclass
from enum import Enum
from urllib.parse import unquote

# Import Router v5 for zone resolution
try:
    from bridge.core.router_v5 import resolve_zone, normalize_path, get_luka_root
except ImportError:
    # Fallback for standalone testing
    def resolve_zone(path: str) -> str:
        """Fallback zone resolver."""
        if any(p in path for p in ["/System/", "/usr/", "/etc/", "/bin/", "~/.ssh/"]):
            return "DANGER"
        if any(p in path for p in ["core/", "bridge/core/", "g/docs/governance/"]):
            return "LOCKED"
        return "OPEN"
    
    def normalize_path(path_str: str) -> Tuple[Path, str]:
        """Fallback path normalizer."""
        path = Path(path_str).expanduser().resolve()
        return (path, str(path))
    
    def get_luka_root() -> Path:
        """Fallback root resolver."""
        return Path.home().joinpath("02luka").resolve()


# ============================================================================
# TYPE DEFINITIONS
# ============================================================================

class SecurityViolation(Enum):
    """Types of security violations."""
    PATH_OUTSIDE_ROOT = "PATH_OUTSIDE_ROOT"
    DANGER_ZONE_WRITE = "DANGER_ZONE_WRITE"
    FORBIDDEN_PATH_PATTERN = "FORBIDDEN_PATH_PATTERN"  # Path pattern violation
    FORBIDDEN_CONTENT_PATTERN = "FORBIDDEN_CONTENT_PATTERN"  # Content pattern violation
    PATH_TRAVERSAL = "PATH_TRAVERSAL"
    ABSOLUTE_PATH_ESCAPE = "ABSOLUTE_PATH_ESCAPE"
    INVALID_CHARS = "INVALID_CHARS"
    HOSTILE_CHARS = "HOSTILE_CHARS"  # Null byte, newline, etc.
    EMPTY_PATH = "EMPTY_PATH"
    LOCKED_ZONE_NO_AUTH = "LOCKED_ZONE_NO_AUTH"
    SIP_VIOLATION = "SIP_VIOLATION"
    MISSING_ROLLBACK = "MISSING_ROLLBACK"
    MISSING_AUDIT = "MISSING_AUDIT"


@dataclass
class SandboxCheckResult:
    """Result of sandbox security check."""
    allowed: bool
    violation: Optional[SecurityViolation] = None
    reason: str = ""
    zone: Optional[str] = None
    normalized_path: Optional[Path] = None
    checksum: Optional[str] = None
    warnings: List[str] = None
    
    def __post_init__(self):
        if self.warnings is None:
            self.warnings = []


# ============================================================================
# FORBIDDEN PATTERNS (from GOVERNANCE v5 Section 6 + sandbox_policy_v1.md)
# ============================================================================

# Command patterns that must not appear in file content
FORBIDDEN_COMMAND_PATTERNS = [
    (r"rm\s+-rf\s+", "Recursive delete without validation"),
    (r"rm\s+-r\s+-f\s+", "Recursive delete (split form)"),
    (r"mv\s+/", "Moving root-level paths"),
    (r"sudo\s+", "Privilege escalation"),
    (r"kill\s+-9\s+", "Force kill"),
    (r":\s*\{\s*:\s*\|", "Fork bomb pattern"),
    (r"chmod\s+777\s+", "World-writable permissions"),
    (r"dd\s+if=/dev/", "Raw disk copy"),
    (r"mkfs\.", "Filesystem formatting"),
    (r"shutdown\s+", "System shutdown"),
    (r"reboot\s+", "System reboot"),
    (r"curl\s+.*\s*\|\s*sh\s*$", "Remote install pipeline"),
    (r"wget\s+.*\s*\|\s*sh\s*$", "Remote install pipeline"),
    (r"python.*os\.remove\(", "Inline Python os.remove"),
    (r"subprocess\.call\(.*rm", "Subprocess delete"),
]

# Path patterns that must not be written to
FORBIDDEN_PATH_PATTERNS = [
    r"^/$",  # Root
    r"^/System/",
    r"^/usr/",
    r"^/bin/",
    r"^/sbin/",
    r"^/etc/",
    r"^~/.ssh/",
    r"\.\./\.\./",  # Path traversal
    r"^\.\./",  # Parent directory escape
]

# Allowed root directories (relative to 02luka)
# NOTE: These are checked against rel_path (relative to 02luka root)
# Absolute path hazards (/System/, /usr/, etc.) are checked in validate_path_syntax()
# via FORBIDDEN_PATH_PATTERNS, not here.
ALLOWED_ROOTS = [
    "apps/",
    "tools/",
    "agents/",
    "tests/",
    "g/reports/",
    "g/docs/",
    "bridge/",
    "core/",  # Allowed but requires LOCKED zone checks
    "launchd/",  # Allowed but requires LOCKED zone checks
]


# ============================================================================
# PATH VALIDATION FUNCTIONS
# ============================================================================

# Hostile characters that must never appear in paths
HOSTILE_CHARS = ["\x00", "\n", "\r", "\t"]  # Null byte, newline, carriage return, tab

# System DANGER prefixes (absolute paths that must be blocked)
DANGER_PREFIXES = [
    "/etc",
    "/bin",
    "/sbin",
    "/usr",
    "/System",
    "/Library",
    "/var",
    "/tmp",  # Can be dangerous if not properly scoped
]


def _normalize_and_validate_raw_path(raw_path: str, root: Path) -> Tuple[Path, Optional[SecurityViolation], str]:
    """
    Normalize and validate raw path input with comprehensive security checks.
    
    Steps:
    1. Decode URL encoding (%2e → ., etc.)
    2. Reject hostile characters (null byte, newline, etc.)
    3. Reject empty/whitespace-only paths
    4. Block path traversal patterns (even encoded variants)
    5. Build absolute path under root (if relative)
    6. Resolve() to eliminate .. and symlinks
    7. Verify path is within root using relative_to()
    8. Check against DANGER prefixes
    
    Args:
        raw_path: Raw path string from input
        root: Root directory (LUKA_SOT)
    
    Returns:
        (resolved_path, violation, reason)
        If violation is None, path is safe to use.
    
    Raises:
        SecurityViolation via return tuple (not exception for easier handling)
    """
    # Step 1: Handle None/empty
    if raw_path is None:
        return (None, SecurityViolation.EMPTY_PATH, "Empty path: None")
    
    # Step 2: Decode URL encoding
    try:
        decoded = unquote(str(raw_path))
    except Exception as e:
        return (None, SecurityViolation.INVALID_CHARS, f"URL decode failed: {e}")
    
    # Step 3: Reject empty/whitespace-only
    if not decoded.strip():
        return (None, SecurityViolation.EMPTY_PATH, "Empty path after strip")
    
    # Step 4: Check hostile characters (null byte, newline, etc.)
    for ch in HOSTILE_CHARS:
        if ch in decoded:
            return (None, SecurityViolation.HOSTILE_CHARS, f"Hostile character in path: {repr(ch)}")
    
    # Step 5: Block path traversal patterns (including encoded variants)
    # Check before resolve() to catch encoded patterns like %2e%2e
    lowered = decoded.lower()
    traversal_patterns = [
        r"\.\./",           # ../
        r"\.\.\\",          # ..\
        r"%2e%2e",          # %2e%2e (encoded ..)
        r"%2e/",            # %2e/ (encoded ./)
        r"/%2e",            # /%2e
        r"\.\.%2f",         # ..%2f
        r"%2e%2e%2f",       # %2e%2e%2f
        r"%c0%af",          # Unicode overlong encoding for /
        r"%c1%9c",          # Unicode overlong encoding for \
        r"\.\.%c0%af",      # ..%c0%af (Unicode encoded ..)
        r"\.\.%c1%9c",      # ..%c1%9c (Unicode encoded ..)
    ]
    for pattern in traversal_patterns:
        if re.search(pattern, lowered):
            return (None, SecurityViolation.PATH_TRAVERSAL, f"Path traversal pattern detected: {pattern}")
    
    # Also check the decoded string for ".." after URL decode
    # This catches Unicode-encoded variants that decode to ".."
    if ".." in decoded:
        return (None, SecurityViolation.PATH_TRAVERSAL, "Path contains '..' (parent directory reference)")
    
    # Step 6: Build absolute path
    try:
        p = Path(decoded)
        if not p.is_absolute():
            p = root / p
    except Exception as e:
        return (None, SecurityViolation.INVALID_CHARS, f"Path construction failed: {e}")
    
    # Step 7: Resolve to eliminate .. and symlinks
    try:
        resolved = p.resolve()
    except Exception as e:
        return (None, SecurityViolation.PATH_TRAVERSAL, f"Cannot resolve path (may contain invalid traversal): {e}")
    
    # Step 8: Verify path is within root using relative_to()
    # This handles exact boundary matches correctly
    try:
        resolved.relative_to(root.resolve())
    except ValueError:
        # Path escapes root → DANGER zone
        return (None, SecurityViolation.PATH_OUTSIDE_ROOT, "Path escapes root (DANGER zone)")
    
    # Step 9: Check against DANGER prefixes (hard deny)
    resolved_str = str(resolved)
    for prefix in DANGER_PREFIXES:
        if resolved_str.startswith(prefix):
            return (None, SecurityViolation.DANGER_ZONE_WRITE, f"Path is under system DANGER prefix: {prefix}")
    
    # Step 10: Check ~/.ssh (DANGER zone)
    home = Path.home()
    ssh_dir = home / ".ssh"
    try:
        resolved.relative_to(ssh_dir)
        return (None, SecurityViolation.DANGER_ZONE_WRITE, "Path targets ~/.ssh (DANGER zone)")
    except ValueError:
        pass  # Not under ~/.ssh, continue
    
    # Path is safe
    return (resolved, None, "")


def validate_path_syntax(path_str: str) -> Tuple[bool, Optional[SecurityViolation], str]:
    """
    Validate path syntax for security issues.
    
    Uses comprehensive normalization and validation via _normalize_and_validate_raw_path().
    
    Checks:
    - URL-encoded traversal patterns (%2e, etc.)
    - Hostile characters (null byte, newline, tab)
    - Empty/whitespace-only paths
    - Path traversal (including encoded variants)
    - Absolute path escapes (/System/, /usr/, etc.)
    - Invalid characters
    - Forbidden patterns
    
    NOTE: Path traversal check is STRICT (100% block) - agents must send normalized paths.
    See HOWTO_TWO_WORLDS_v2.md FAQ for path normalization requirements.
    
    Returns:
        (is_valid, violation_type, reason)
    """
    luka_root = get_luka_root()
    
    # Use comprehensive normalization and validation
    resolved, violation, reason = _normalize_and_validate_raw_path(path_str, luka_root)
    
    if violation is not None:
        return (False, violation, reason)
    
    # Additional checks for OS-specific invalid characters (Windows/Mac)
    invalid_chars = ['<', '>', '"', '|', '?', '*']
    # Note: ':' is allowed on Mac/Linux but not Windows - we'll be permissive here
    path_str_clean = str(resolved) if resolved else path_str
    for char in invalid_chars:
        if char in path_str_clean:
            return (False, SecurityViolation.INVALID_CHARS, f"Path contains invalid character: {char}")
    
    # Check for forbidden path patterns (additional patterns not caught by normalization)
    for pattern in FORBIDDEN_PATH_PATTERNS:
        if re.search(pattern, path_str_clean):
            return (
                False,
                SecurityViolation.FORBIDDEN_PATH_PATTERN,
                f"Path matches forbidden absolute/system pattern: {pattern}"
            )
    
    return (True, None, "")


def validate_path_within_root(path_str: str) -> Tuple[bool, Path, str]:
    """
    Validate that path is within 02luka root.
    
    Uses _normalize_and_validate_raw_path() for comprehensive validation.
    
    Returns:
        (is_valid, normalized_path, relative_path)
    """
    luka_root = get_luka_root()
    
    # Use comprehensive normalization and validation
    resolved, violation, reason = _normalize_and_validate_raw_path(path_str, luka_root)
    
    if violation is not None:
        return (False, resolved, reason)
    
    # Get relative path for return
    try:
        rel_path = str(resolved.relative_to(luka_root.resolve()))
    except ValueError:
        return (False, resolved, "Path is outside 02luka root")
    
    return (True, resolved, rel_path)


def check_path_allowed(rel_path: str) -> Tuple[bool, str]:
    """
    Check if relative path is in allowed roots.
    
    Logic:
    - Must start with one of ALLOWED_ROOTS
    - NOTE: Absolute path hazards (/System/, /usr/, etc.) are already checked
      in validate_path_syntax() via FORBIDDEN_PATH_PATTERNS.
      This function only checks relative path policy within 02luka root.
    
    Returns:
        (is_allowed, reason)
    """
    rel_path = rel_path.replace("\\", "/")
    
    # Check allowed roots
    for allowed in ALLOWED_ROOTS:
        allowed_clean = allowed.rstrip("/")
        if rel_path.startswith(allowed_clean):
            # Check boundary: either end of string or path separator follows
            # This prevents prefix collision (e.g., "g/srcfoo/" matching "g/src/")
            if len(rel_path) == len(allowed_clean) or rel_path[len(allowed_clean)] == "/":
                return (True, f"Path allowed (root: {allowed_clean})")
    
    return (False, "Path not in allowed roots (must start with one of: apps/, tools/, agents/, tests/, g/reports/, g/docs/, bridge/, core/, launchd/)")


# ============================================================================
# CONTENT VALIDATION FUNCTIONS
# ============================================================================

def scan_content_for_forbidden_patterns(content: str) -> List[Tuple[str, str]]:
    """
    Scan file content for forbidden command patterns.
    
    Returns:
        List of (pattern, description) tuples for violations found
    """
    violations = []
    
    for pattern, description in FORBIDDEN_COMMAND_PATTERNS:
        if re.search(pattern, content, re.IGNORECASE | re.MULTILINE):
            violations.append((pattern, description))
    
    return violations


def validate_content_safety(content: str, file_path: Optional[str] = None) -> Tuple[bool, List[str]]:
    """
    Validate file content for safety.
    
    Checks:
    - Forbidden command patterns
    - Dangerous code constructs
    
    Returns:
        (is_safe, list_of_warnings)
    """
    warnings = []
    
    # Scan for forbidden patterns
    violations = scan_content_for_forbidden_patterns(content)
    
    if violations:
        for pattern, desc in violations:
            warnings.append(f"Forbidden pattern detected: {pattern} ({desc})")
    
    # Additional checks for specific file types
    if file_path:
        ext = Path(file_path).suffix.lower()
        
        if ext == ".sh" or ext == ".zsh":
            # Shell scripts: extra strict
            if "rm -rf" in content or "rm -r -f" in content:
                warnings.append("Shell script contains recursive delete - requires validation")
        
        if ext == ".py":
            # Python: check for dangerous imports/operations
            if "os.remove" in content or "shutil.rmtree" in content:
                warnings.append("Python script contains file deletion operations - requires validation")
    
    is_safe = len(warnings) == 0
    
    return (is_safe, warnings)


# ============================================================================
# ZONE-BASED VALIDATION
# ============================================================================

def check_zone_permissions(
    zone: str,
    actor: str,
    operation: str,
    context: Optional[Dict] = None
) -> Tuple[bool, Optional[SecurityViolation], str]:
    """
    Check if actor has permission to perform operation in zone.
    
    Logic (GOVERNANCE v5 Section 4.2, PERSONA_MODEL_v5 Section 3):
    - DANGER zone: Only Boss with explicit confirmation
    - LOCKED zone: Boss/CLS override or WO → CLC
    - OPEN zone: Allowed for CLI writers
    
    Returns:
        (is_allowed, violation_type, reason)
    """
    if zone == "DANGER":
        # DANGER zone: Only Boss with explicit confirmation
        if actor == "Boss" and context and context.get("boss_confirmed_danger"):
            return (True, None, "Boss explicitly confirmed DANGER zone operation")
        return (False, SecurityViolation.DANGER_ZONE_WRITE, "DANGER zone write requires Boss explicit confirmation")
    
    if zone == "LOCKED":
        # LOCKED zone: Boss/CLS override or WO → CLC
        if actor == "Boss":
            return (True, None, "Boss override allowed for LOCKED zone")
        
        if actor == "CLS":
            # Check for auto-approve conditions
            if context and context.get("cls_auto_approve_allowed"):
                return (True, None, "CLS auto-approve allowed (Mission Scope + safety conditions)")
            # Otherwise requires Boss/CLS explicit instruction
            if context and context.get("boss_cls_authorized"):
                return (True, None, "Boss/CLS authorized LOCKED zone write")
        
        # Background world: Must have WO
        if context and context.get("wo_id"):
            return (True, None, "Background world with WO → CLC")
        
        return (False, SecurityViolation.LOCKED_ZONE_NO_AUTH, "LOCKED zone requires Boss/CLS authorization or WO")
    
    if zone == "OPEN":
        # OPEN zone: Allowed for CLI writers
        cli_writers = ["Boss", "CLS", "Liam", "GMX", "Codex", "Gemini", "LAC"]
        if actor in cli_writers:
            return (True, None, "OPEN zone write allowed for CLI writer")
        
        # Background world: Still allowed but requires audit
        if context and context.get("wo_id"):
            return (True, None, "OPEN zone write allowed with WO (background)")
    
    return (True, None, "Operation allowed")


# ============================================================================
# SIP VALIDATION (Safe Idempotent Patch)
# ============================================================================

def validate_sip_compliance(
    file_path: str,
    temp_file: Optional[str] = None,
    checksum_before: Optional[str] = None,
    checksum_after: Optional[str] = None
) -> Tuple[bool, Optional[SecurityViolation], str]:
    """
    Validate that write operation follows SIP (Safe Idempotent Patch).
    
    SIP Requirements (AI_OP_001_v5 Section 5.2):
    1. Write to temp file first
    2. Validate temp file
    3. Atomic move (mv temp target)
    4. Post-write verification (checksum)
    
    Returns:
        (is_compliant, violation_type, reason)
    """
    if temp_file is None:
        return (False, SecurityViolation.SIP_VIOLATION, "SIP requires temp file (mktemp → write → mv)")
    
    # Check that temp file exists
    if not Path(temp_file).exists():
        return (False, SecurityViolation.SIP_VIOLATION, "SIP temp file does not exist")
    
    # Check that checksums are provided
    if checksum_before is None or checksum_after is None:
        return (False, SecurityViolation.SIP_VIOLATION, "SIP requires checksum before and after")
    
    return (True, None, "SIP compliance verified")


def compute_file_checksum(file_path: str) -> Optional[str]:
    """Compute SHA256 checksum of file."""
    try:
        with open(file_path, 'rb') as f:
            return hashlib.sha256(f.read()).hexdigest()
    except Exception:
        return None


# ============================================================================
# MAIN SANDBOX CHECK FUNCTION
# ============================================================================

def check_write_allowed(
    path: str,
    actor: str,
    operation: str = "write",
    content: Optional[str] = None,
    context: Optional[Dict] = None
) -> SandboxCheckResult:
    """
    Main sandbox check function (pre-write interception).
    
    This function performs all security checks before allowing a write:
    1. Path syntax validation
    2. Path within root validation
    3. Zone resolution
    4. Zone permission check
    5. Content safety validation (if content provided)
    6. SIP compliance check (if applicable)
    
    Args:
        path: Target file path
        actor: Acting agent
        operation: Operation type (write/delete/move)
        content: File content (optional, for content validation)
        context: Optional context (WO id, rollback strategy, etc.)
    
    Returns:
        SandboxCheckResult with all validation information
    """
    warnings = []
    
    # Step 1: Validate path syntax
    is_valid, violation, reason = validate_path_syntax(path)
    if not is_valid:
        return SandboxCheckResult(
            allowed=False,
            violation=violation,
            reason=reason
        )
    
    # Step 2: Validate path within root
    is_valid, normalized_path, rel_path = validate_path_within_root(path)
    if not is_valid:
        return SandboxCheckResult(
            allowed=False,
            violation=SecurityViolation.PATH_OUTSIDE_ROOT,
            reason=rel_path or "Path outside 02luka root"
        )
    
    # Step 3: Check path allowed roots
    is_allowed, allow_reason = check_path_allowed(rel_path)
    if not is_allowed:
        return SandboxCheckResult(
            allowed=False,
            violation=SecurityViolation.FORBIDDEN_PATH_PATTERN,
            reason=f"Path policy violation: {allow_reason}",
            normalized_path=normalized_path
        )
    
    # Step 4: Resolve zone
    zone = resolve_zone(path)
    
    # Step 5: Check zone permissions
    is_allowed, violation, reason = check_zone_permissions(zone, actor, operation, context)
    if not is_allowed:
        return SandboxCheckResult(
            allowed=False,
            violation=violation,
            reason=reason,
            zone=zone,
            normalized_path=normalized_path
        )
    
    # Step 6: Validate content safety (if content provided)
    if content is not None:
        is_safe, content_warnings = validate_content_safety(content, path)
        warnings.extend(content_warnings)
        
        if not is_safe:
            return SandboxCheckResult(
                allowed=False,
                violation=SecurityViolation.FORBIDDEN_CONTENT_PATTERN,
                reason="Content contains forbidden command patterns (e.g., rm -rf, sudo, curl | sh). See sandbox_guard_config.yaml for full list.",
                zone=zone,
                normalized_path=normalized_path,
                warnings=warnings
            )
    
    # Step 7: Check SIP compliance (if in background world or LOCKED zone)
    if context:
        world = context.get("world", "CLI")
        if world == "BACKGROUND" or zone == "LOCKED":
            temp_file = context.get("temp_file")
            checksum_before = context.get("checksum_before")
            checksum_after = context.get("checksum_after")
            
            is_compliant, violation, reason = validate_sip_compliance(
                path, temp_file, checksum_before, checksum_after
            )
            
            if not is_compliant:
                warnings.append(f"SIP compliance issue: {reason}")
                # SIP violation is a warning for CLI, error for BACKGROUND
                if world == "BACKGROUND":
                    return SandboxCheckResult(
                        allowed=False,
                        violation=SecurityViolation.SIP_VIOLATION,
                        reason=reason,
                        zone=zone,
                        normalized_path=normalized_path,
                        warnings=warnings
                    )
    
    # Step 8: Check rollback strategy (if required)
    if zone == "LOCKED" or zone == "DANGER":
        if context and not context.get("rollback_strategy"):
            warnings.append("Rollback strategy recommended for LOCKED/DANGER zone operations")
    
    # Step 9: Compute checksum if file exists
    checksum = None
    if normalized_path and normalized_path.exists():
        checksum = compute_file_checksum(str(normalized_path))
    
    # All checks passed
    return SandboxCheckResult(
        allowed=True,
        reason="All security checks passed",
        zone=zone,
        normalized_path=normalized_path,
        checksum=checksum,
        warnings=warnings
    )


# ============================================================================
# CLI INTERFACE
# ============================================================================

def main():
    """CLI entry point for sandbox guard."""
    import argparse
    import json
    
    parser = argparse.ArgumentParser(
        description="SandboxGuard v5 — Security Boundary Enforcement"
    )
    parser.add_argument("--path", required=True, help="Target file path")
    parser.add_argument("--actor", required=True, help="Acting agent")
    parser.add_argument("--op", default="write", choices=["write", "delete", "move"])
    parser.add_argument("--content", help="File content (for validation)")
    parser.add_argument("--context", help="Context JSON (optional)")
    parser.add_argument("--json", action="store_true", help="Output JSON")
    
    args = parser.parse_args()
    
    context = None
    if args.context:
        context = json.loads(args.context)
    
    result = check_write_allowed(
        path=args.path,
        actor=args.actor,
        operation=args.op,
        content=args.content,
        context=context
    )
    
    if args.json:
        output = {
            "allowed": result.allowed,
            "violation": result.violation.value if result.violation else None,
            "reason": result.reason,
            "zone": result.zone,
            "normalized_path": str(result.normalized_path) if result.normalized_path else None,
            "checksum": result.checksum,
            "warnings": result.warnings,
        }
        print(json.dumps(output, indent=2))
    else:
        if result.allowed:
            print("✅ SANDBOX CHECK: ALLOWED")
            print(f"   PATH  : {result.normalized_path}")
            print(f"   ZONE  : {result.zone}")
            if result.warnings:
                print(f"   ⚠️ WARNINGS: {', '.join(result.warnings)}")
        else:
            print("❌ SANDBOX CHECK: BLOCKED")
            print(f"   PATH     : {result.normalized_path}")
            print(f"   ZONE     : {result.zone}")
            print(f"   VIOLATION: {result.violation.value if result.violation else 'Unknown'}")
            print(f"   REASON   : {result.reason}")


if __name__ == "__main__":
    main()

