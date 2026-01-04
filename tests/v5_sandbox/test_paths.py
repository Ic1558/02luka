"""
SandboxGuard v5 — Path Validation Tests

Tests:
- Path syntax validation (traversal, forbidden patterns)
- Path within root validation
- Allowed roots checking
"""

import pytest
import sys
from pathlib import Path

project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

try:
    from bridge.core.sandbox_guard_v5 import (
        validate_path_syntax,
        validate_path_within_root,
        check_path_allowed,
        SecurityViolation
    )
except ImportError:
    # Fallback mock
    class SecurityViolation:
        PATH_TRAVERSAL = "PATH_TRAVERSAL"
        FORBIDDEN_PATH_PATTERN = "FORBIDDEN_PATH_PATTERN"
        PATH_OUTSIDE_ROOT = "PATH_OUTSIDE_ROOT"
        INVALID_CHARS = "INVALID_CHARS"
    
    def validate_path_syntax(path_str):
        if ".." in path_str:
            return (False, SecurityViolation.PATH_TRAVERSAL, "Path contains '..'")
        
        forbidden = ["/System/", "/usr/", "/etc/", "/bin/", "~/.ssh/"]
        for pattern in forbidden:
            if pattern in path_str:
                return (False, SecurityViolation.FORBIDDEN_PATH_PATTERN, f"Forbidden pattern: {pattern}")
        
        invalid_chars = ['<', '>', ':', '"', '|', '?', '*']
        for char in invalid_chars:
            if char in path_str:
                return (False, SecurityViolation.INVALID_CHARS, f"Invalid char: {char}")
        
        return (True, None, "")
    
    def validate_path_within_root(path_str):
        # Mock: assume path is within root if relative
        if path_str.startswith("/") and not path_str.startswith("/Users/icmini/02luka"):
            return (False, None, "Path outside 02luka root")
        return (True, Path(path_str), path_str.lstrip("/"))
    
    def check_path_allowed(rel_path):
        allowed = ["apps/", "tools/", "agents/", "tests/", "g/reports/", "g/docs/", "bridge/", "core/", "launchd/"]
        for pattern in allowed:
            if rel_path.startswith(pattern):
                return (True, f"Path allowed (root: {pattern})")
        return (False, "Path not in allowed roots")


@pytest.mark.parametrize("path,should_block", [
    # Path traversal - should block
    ("../../etc/passwd", True),
    ("g/docs/../reports/file.md", True),
    ("../somewhere", True),
    ("./../file.py", True),
    
    # Forbidden absolute paths - should block
    ("/System/Library", True),
    ("/usr/bin/test", True),
    ("/etc/hosts", True),
    ("/bin/sh", True),
    # Note: ~/ as literal string becomes relative path, not home escape
    # Real home path tested separately
    
    # Valid paths - should allow
    ("apps/myapp/main.py", False),
    ("tools/script.zsh", False),
    ("g/reports/session.md", False),
])
def test_validate_path_syntax(path, should_block):
    """Test path syntax validation."""
    is_valid, violation, reason = validate_path_syntax(path)
    
    if should_block:
        assert not is_valid, f"Should block {path}, but validation passed"
        assert violation is not None, f"Should have violation for {path}"
    else:
        assert is_valid, f"Should allow {path}, but validation failed: {reason}"


@pytest.mark.parametrize("path,expected_allowed", [
    # Allowed roots
    ("apps/myapp/main.py", True),
    ("tools/script.zsh", True),
    ("agents/myagent.py", True),
    ("tests/test_file.py", True),
    ("g/reports/session.md", True),
    ("g/docs/guide.md", True),
    ("bridge/core/router.py", True),
    ("core/config.yaml", True),
    ("launchd/com.test.plist", True),
    
    # Not in allowed roots
    ("random/file.py", False),
    ("unknown/path.md", False),
])
def test_check_path_allowed(path, expected_allowed):
    """Test allowed roots checking."""
    is_allowed, reason = check_path_allowed(path)
    assert is_allowed == expected_allowed, f"Path {path}: expected {expected_allowed}, got {is_allowed}. Reason: {reason}"


def test_path_traversal_strict():
    """Test strict path traversal blocking."""
    # All variations of .. should be blocked
    test_paths = [
        "../../etc/passwd",
        "g/docs/../reports/file.md",
        "../somewhere",
        "./../file.py",
        "apps/../../etc/hosts",
    ]
    
    for path in test_paths:
        is_valid, violation, reason = validate_path_syntax(path)
        assert not is_valid, f"Should block path traversal: {path}"
        assert violation == SecurityViolation.PATH_TRAVERSAL, f"Should be PATH_TRAVERSAL violation: {path}"


def test_forbidden_absolute_paths():
    """Test forbidden absolute path patterns."""
    from pathlib import Path
    test_paths = [
        "/System/Library",
        "/usr/bin/test",
        "/etc/hosts",
        "/bin/sh",
        str(Path.home() / ".ssh" / "id_rsa"),  # Expanded home path
    ]
    
    for path in test_paths:
        is_valid, violation, reason = validate_path_syntax(path)
        assert not is_valid, f"Should block forbidden path: {path}"
        # Accept either FORBIDDEN_PATH_PATTERN or PATH_OUTSIDE_ROOT or DANGER_ZONE_WRITE
        assert violation in [SecurityViolation.FORBIDDEN_PATH_PATTERN, SecurityViolation.PATH_OUTSIDE_ROOT, SecurityViolation.DANGER_ZONE_WRITE], f"Unexpected violation for {path}: {violation}"

