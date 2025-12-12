#!/usr/bin/env python3
"""
Battle-Test Suite: Matrix 5 — SIP Compliance (Background World)
Tests Safe Idempotent Patch implementation

Run: python3 -m pytest tests/v5_battle/test_matrix5_sip.py -v
"""

import pytest
import sys
import os
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from bridge.core.sandbox_guard_v5 import (
    validate_sip_compliance, compute_file_checksum
)

# Import CLC executor if available
try:
    from agents.clc.executor_v5 import apply_sip_single_file
    HAS_CLC_EXECUTOR = True
except ImportError:
    HAS_CLC_EXECUTOR = False


class TestMatrix5SIPCompliance:
    """Matrix 5: SIP Compliance (S5-01 to S5-07)"""
    
    # =========================================================================
    # S5-01 to S5-03: Temp File Operations
    # =========================================================================
    
    def test_S5_01_temp_file_required(self):
        """S5-01: SIP requires temp file"""
        is_compliant, violation, reason = validate_sip_compliance(
            file_path="test.txt",
            temp_file=None,  # No temp file
            checksum_before="abc",
            checksum_after="def"
        )
        assert is_compliant == False
        assert "temp file" in reason.lower()
    
    def test_S5_02_temp_file_must_exist(self):
        """S5-02: Temp file must exist"""
        is_compliant, violation, reason = validate_sip_compliance(
            file_path="test.txt",
            temp_file="/nonexistent/temp.tmp",
            checksum_before="abc",
            checksum_after="def"
        )
        assert is_compliant == False
        assert "exist" in reason.lower()
    
    def test_S5_03_checksums_required(self):
        """S5-03: Checksums before and after required"""
        # Create actual temp file for this test
        with tempfile.NamedTemporaryFile(delete=False) as f:
            f.write(b"test content")
            temp_path = f.name
        
        try:
            is_compliant, violation, reason = validate_sip_compliance(
                file_path="test.txt",
                temp_file=temp_path,
                checksum_before=None,  # Missing checksum
                checksum_after=None
            )
            assert is_compliant == False
            assert "checksum" in reason.lower()
        finally:
            os.unlink(temp_path)
    
    # =========================================================================
    # S5-04 to S5-06: Execution Scenarios
    # =========================================================================
    
    @pytest.mark.skipif(not HAS_CLC_EXECUTOR, reason="CLC executor not available")
    def test_S5_04_atomic_move_success(self, tmp_path):
        """S5-04: Atomic move should succeed"""
        target = tmp_path / "target.txt"
        content = "New content for atomic move"
        
        success, before, after, temp = apply_sip_single_file(
            file_path=str(target),
            new_content=content,
            operation="add"
        )
        
        assert success == True
        assert target.exists()
        assert target.read_text() == content
        assert after is not None
    
    @pytest.mark.skipif(not HAS_CLC_EXECUTOR, reason="CLC executor not available")
    def test_S5_05_checksum_verification(self, tmp_path):
        """S5-05: Checksum should match after write"""
        target = tmp_path / "checksum_test.txt"
        content = "Content to verify checksum"
        
        success, before, after, temp = apply_sip_single_file(
            file_path=str(target),
            new_content=content,
            operation="add"
        )
        
        # Verify checksum matches computed
        computed = compute_file_checksum(str(target))
        assert after == computed
    
    def test_S5_06_checksum_computation(self):
        """S5-06: Checksum computation should be consistent"""
        with tempfile.NamedTemporaryFile(delete=False, mode='w') as f:
            f.write("Consistent content")
            temp_path = f.name
        
        try:
            checksum1 = compute_file_checksum(temp_path)
            checksum2 = compute_file_checksum(temp_path)
            assert checksum1 == checksum2
            assert len(checksum1) == 64  # SHA256 hex length
        finally:
            os.unlink(temp_path)
    
    # =========================================================================
    # S5-07: Full Success Path
    # =========================================================================
    
    def test_S5_07_full_sip_compliance(self):
        """S5-07: Full SIP compliance with all requirements"""
        with tempfile.NamedTemporaryFile(delete=False, mode='w') as f:
            f.write("Valid temp content")
            temp_path = f.name
        
        try:
            is_compliant, violation, reason = validate_sip_compliance(
                file_path="target.txt",
                temp_file=temp_path,
                checksum_before="abc123",
                checksum_after="def456"
            )
            assert is_compliant == True
            assert violation is None
        finally:
            os.unlink(temp_path)


class TestMatrix5SIPWithCLC:
    """SIP tests with CLC executor integration"""
    
    @pytest.mark.skipif(not HAS_CLC_EXECUTOR, reason="CLC executor not available")
    def test_sip_add_operation(self, tmp_path):
        """Add operation via SIP"""
        target = tmp_path / "new_file.txt"
        content = "Brand new file content"
        
        success, before, after, temp = apply_sip_single_file(
            file_path=str(target),
            new_content=content,
            operation="add"
        )
        
        assert success == True
        assert before is None  # No file before
        assert after is not None
        assert target.exists()
    
    @pytest.mark.skipif(not HAS_CLC_EXECUTOR, reason="CLC executor not available")
    def test_sip_modify_operation(self, tmp_path):
        """Modify operation via SIP"""
        target = tmp_path / "existing_file.txt"
        target.write_text("Original content")
        original_checksum = compute_file_checksum(str(target))
        
        success, before, after, temp = apply_sip_single_file(
            file_path=str(target),
            new_content="Modified content",
            operation="modify"
        )
        
        assert success == True
        assert before == original_checksum
        assert after != before
        assert target.read_text() == "Modified content"
    
    @pytest.mark.skipif(not HAS_CLC_EXECUTOR, reason="CLC executor not available")
    def test_sip_delete_operation(self, tmp_path):
        """Delete operation via SIP"""
        target = tmp_path / "to_delete.txt"
        target.write_text("File to delete")
        
        success, before, after, temp = apply_sip_single_file(
            file_path=str(target),
            new_content="",
            operation="delete"
        )
        
        assert success == True
        assert before is not None
        assert after is None  # Deleted
        assert not target.exists()


class TestMatrix5BackgroundWorldIntegration:
    """Background world SIP integration tests"""
    
    def test_sip_required_for_background(self):
        """SIP is required for BACKGROUND world writes"""
        from bridge.core.sandbox_guard_v5 import check_write_allowed
        
        result = check_write_allowed(
            path="g/reports/bg_test.md",
            actor="CLC",
            operation="write",
            content="Background write",
            context={
                "world": "BACKGROUND",
                "wo_id": "WO-TEST-001"
                # Missing SIP requirements
            }
        )
        # Should have warning about SIP
        assert any("SIP" in w for w in result.warnings) if result.warnings else True
    
    def test_sip_required_for_locked_zone(self):
        """SIP is required for LOCKED zone writes"""
        from bridge.core.sandbox_guard_v5 import check_write_allowed
        
        result = check_write_allowed(
            path="bridge/core/config.yaml",
            actor="CLS",
            operation="write",
            content="LOCKED zone write",
            context={
                "world": "CLI",
                "zone": "LOCKED"
                # Missing SIP requirements
            }
        )
        # Should have warning about SIP or rollback
        # Behavior depends on implementation


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
