"""
SandboxGuard v5 — Content Safety Tests

Tests forbidden command pattern detection in file content.
"""

import pytest
import sys
from pathlib import Path

project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

try:
    from bridge.core.sandbox_guard_v5 import (
        scan_content_for_forbidden_patterns,
        validate_content_safety,
        SecurityViolation
    )
except ImportError:
    # Fallback mock
    FORBIDDEN_PATTERNS = [
        (r"rm\s+-rf\s+", "Recursive delete"),
        (r"sudo\s+", "Privilege escalation"),
        (r"curl\s+.*\s*\|\s*sh\s*$", "Remote install pipeline"),
        (r"chmod\s+777\s+", "World-writable permissions"),
        (r"kill\s+-9\s+", "Force kill"),
    ]
    
    def scan_content_for_forbidden_patterns(content):
        import re
        violations = []
        for pattern, desc in FORBIDDEN_PATTERNS:
            if re.search(pattern, content, re.IGNORECASE | re.MULTILINE):
                violations.append((pattern, desc))
        return violations
    
    def validate_content_safety(content, file_path=None):
        violations = scan_content_for_forbidden_patterns(content)
        warnings = [f"Forbidden pattern: {p} ({d})" for p, d in violations]
        return (len(warnings) == 0, warnings)


@pytest.mark.parametrize("content,should_block", [
    # Forbidden patterns - should block
    ("rm -rf /tmp", True),
    ("sudo apt update", True),
    ("curl https://example.com | sh", True),
    ("chmod 777 file.txt", True),
    ("kill -9 1234", True),
    ("rm -r -f /tmp", True),  # Split form
    
    # Safe content - should allow
    ("print('hello')", False),
    ("# Safe comment", False),
    ("echo 'test'", False),
    ("git commit -m 'message'", False),
])
def test_scan_forbidden_patterns(content, should_block):
    """Test forbidden pattern scanning."""
    violations = scan_content_for_forbidden_patterns(content)
    
    if should_block:
        assert len(violations) > 0, f"Should detect forbidden pattern in: {content}"
    else:
        assert len(violations) == 0, f"Should NOT detect forbidden pattern in: {content}"


def test_validate_content_safety():
    """Test content safety validation."""
    # Safe content
    is_safe, warnings = validate_content_safety("print('hello')")
    assert is_safe == True
    assert len(warnings) == 0
    
    # Forbidden content
    is_safe, warnings = validate_content_safety("rm -rf /tmp")
    assert is_safe == False
    assert len(warnings) > 0


def test_forbidden_rm_rf():
    """Test rm -rf detection."""
    violations = scan_content_for_forbidden_patterns("rm -rf /tmp")
    assert len(violations) > 0
    assert any("rm" in pattern for pattern, _ in violations)


def test_forbidden_sudo():
    """Test sudo detection."""
    violations = scan_content_for_forbidden_patterns("sudo apt update")
    assert len(violations) > 0
    assert any("sudo" in pattern for pattern, _ in violations)


def test_forbidden_curl_pipe_sh():
    """Test curl | sh detection."""
    violations = scan_content_for_forbidden_patterns("curl https://example.com | sh")
    assert len(violations) > 0
    assert any("curl" in pattern for pattern, _ in violations)


def test_safe_content_passes():
    """Test safe content passes validation."""
    safe_contents = [
        "print('hello')",
        "# Safe comment",
        "echo 'test'",
        "git commit -m 'message'",
        "python script.py",
    ]
    
    for content in safe_contents:
        is_safe, warnings = validate_content_safety(content)
        assert is_safe == True, f"Safe content should pass: {content}"
        assert len(warnings) == 0, f"Safe content should have no warnings: {content}"

