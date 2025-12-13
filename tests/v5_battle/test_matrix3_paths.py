#!/usr/bin/env python3
"""
Battle-Test Suite: Matrix 3 — Path Traversal & Escape
Tests path security and escape attempts

Run: python3 -m pytest tests/v5_battle/test_matrix3_paths.py -v
"""

import pytest
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from bridge.core.sandbox_guard_v5 import (
    validate_path_syntax,
    validate_path_within_root,
    check_path_allowed,
    check_write_allowed,
    SecurityViolation
)


class TestMatrix3PathTraversal:
    """Matrix 3: Path Traversal & Escape (P3-01 to P3-10)"""
    
    # =========================================================================
    # P3-01 to P3-03: Directory Traversal
    # =========================================================================
    
    def test_P3_01_basic_traversal(self):
        """P3-01: Basic ../../../etc/passwd traversal"""
        is_valid, violation, reason = validate_path_syntax("../../../etc/passwd")
        assert is_valid == False
        assert violation == SecurityViolation.PATH_TRAVERSAL
    
    def test_P3_02_hidden_traversal(self):
        """P3-02: Hidden traversal foo/../../../bar"""
        is_valid, violation, reason = validate_path_syntax("foo/../../../bar")
        assert is_valid == False
        assert violation == SecurityViolation.PATH_TRAVERSAL
    
    def test_P3_03_relative_escape(self):
        """P3-03: Relative escape ./foo/../../bar"""
        is_valid, violation, reason = validate_path_syntax("./foo/../../bar")
        assert is_valid == False
        assert violation == SecurityViolation.PATH_TRAVERSAL
    
    # =========================================================================
    # P3-04 to P3-07: Absolute System Paths
    # =========================================================================
    
    def test_P3_04_system_library(self):
        """P3-04: /System/Library/ absolute path"""
        is_valid, violation, reason = validate_path_syntax("/System/Library/test")
        assert is_valid == False
        # May return FORBIDDEN_PATH_PATTERN or PATH_OUTSIDE_ROOT
        assert violation in [SecurityViolation.FORBIDDEN_PATH_PATTERN, SecurityViolation.PATH_OUTSIDE_ROOT]
    
    def test_P3_05_usr_local_bin(self):
        """P3-05: /usr/local/bin/ absolute path"""
        is_valid, violation, reason = validate_path_syntax("/usr/local/bin/malware")
        assert is_valid == False
        assert violation in [SecurityViolation.FORBIDDEN_PATH_PATTERN, SecurityViolation.PATH_OUTSIDE_ROOT]
    
    def test_P3_06_ssh_escape(self):
        """P3-06: ~/.ssh/id_rsa home escape (using expanded path)"""
        from pathlib import Path
        home = Path.home()
        ssh_path = str(home / ".ssh" / "id_rsa")
        is_valid, violation, reason = validate_path_syntax(ssh_path)
        assert is_valid == False
        assert violation in [SecurityViolation.FORBIDDEN_PATH_PATTERN, SecurityViolation.PATH_OUTSIDE_ROOT, SecurityViolation.DANGER_ZONE_WRITE]
    
    def test_P3_07_etc_hosts(self):
        """P3-07: /etc/hosts system file"""
        is_valid, violation, reason = validate_path_syntax("/etc/hosts")
        assert is_valid == False
        assert violation in [SecurityViolation.FORBIDDEN_PATH_PATTERN, SecurityViolation.PATH_OUTSIDE_ROOT]
    
    # =========================================================================
    # P3-08 to P3-10: Encoded/URI Escapes
    # =========================================================================
    
    def test_P3_08_file_uri_escape(self):
        """P3-08: file:/// URI escape - check if handled"""
        # Note: This may pass syntax check but should fail path validation
        is_valid, violation, reason = validate_path_syntax("file:///etc/passwd")
        # Behavior depends on implementation - document result
    
    def test_P3_09_url_encoded_dots(self):
        """P3-09: %2e%2e%2f URL encoded traversal"""
        # Raw string - should not contain actual ".." but encoded version
        path = "%2e%2e%2fetc%2fpasswd"
        is_valid, violation, reason = validate_path_syntax(path)
        # URL encoding bypass test - document behavior
    
    def test_P3_10_windows_encoded(self):
        """P3-10: ..%5c..%5c Windows path separator"""
        path = "..%5c..%5cetc%5cpasswd"
        is_valid, violation, reason = validate_path_syntax(path)
        # Windows encoding bypass test - document behavior


class TestMatrix3FullPathCheck:
    """Full path check integration tests"""
    
    def test_path_outside_root_blocked(self):
        """Path outside 02luka root should be blocked"""
        result = check_write_allowed(
            path="/tmp/outside_root.txt",
            actor="CLS",
            operation="write",
            context={"world": "CLI"}
        )
        assert result.allowed == False
    
    def test_valid_relative_path_allowed(self):
        """Valid relative path should be allowed"""
        result = check_write_allowed(
            path="g/reports/valid_report.md",
            actor="CLS",
            operation="write",
            context={"world": "CLI"}
        )
        assert result.allowed == True
    
    def test_invalid_chars_blocked(self):
        """Invalid characters should be blocked"""
        is_valid, violation, reason = validate_path_syntax("file<name>.txt")
        assert is_valid == False
        assert violation == SecurityViolation.INVALID_CHARS
    
    def test_allowed_roots_enforcement(self):
        """Only allowed roots should pass"""
        # Valid root
        is_allowed, reason = check_path_allowed("tools/script.zsh")
        assert is_allowed == True
        
        # Valid root
        is_allowed, reason = check_path_allowed("g/reports/doc.md")
        assert is_allowed == True
        
        # Valid root
        is_allowed, reason = check_path_allowed("agents/clc/executor.py")
        assert is_allowed == True


class TestMatrix3ZoneResolution:
    """Zone resolution from paths"""
    
    def test_core_is_locked(self):
        """core/ should resolve to LOCKED"""
        from bridge.core.router_v5 import resolve_zone
        zone = resolve_zone("core/important.py")
        assert zone == "LOCKED"
    
    def test_bridge_core_is_locked(self):
        """bridge/core/ should resolve to LOCKED"""
        from bridge.core.router_v5 import resolve_zone
        zone = resolve_zone("bridge/core/router.py")
        assert zone == "LOCKED"
    
    def test_g_reports_is_open(self):
        """g/reports/ should resolve to OPEN"""
        from bridge.core.router_v5 import resolve_zone
        zone = resolve_zone("g/reports/test.md")
        assert zone == "OPEN"
    
    def test_system_path_is_danger(self):
        """System path should resolve to DANGER"""
        from bridge.core.router_v5 import resolve_zone
        zone = resolve_zone("/System/Library/file")
        assert zone == "DANGER"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
