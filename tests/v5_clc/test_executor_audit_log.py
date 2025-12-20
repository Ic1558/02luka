#!/usr/bin/env python3
"""
Test CLC Executor v5 Audit Logging

Tests for audit log functionality covering:
- Audit log file creation
- Required fields in audit log
- Log location and naming
"""

import sys
import tempfile
import yaml
import json
from pathlib import Path

# Add project root to path
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

from agents.clc.executor_v5 import (
    read_work_order,
    write_audit_log,
    ExecutionResult,
    WOStatus
)


def test_audit_log_contains_required_fields():
    """Test that audit log contains all required fields."""
    test_dir = Path(tempfile.mkdtemp())
    wo_file = test_dir / "test_wo.yaml"
    
    wo_data = {
        "wo_id": "TEST-AUDIT-001",
        "created_at": "2025-12-10T10:00:00+07:00",
        "origin": {"world": "BACKGROUND", "actor": "CLC"},
        "target_paths": ["g/reports/test.md"],
        "zone_summary": {"g/reports/test.md": "OPEN"},
        "risk_level": "LOW",
        "desired_state": "Test audit",
        "change_type": "ADD"
    }
    
    with open(wo_file, 'w') as f:
        yaml.dump(wo_data, f)
    
    wo = read_work_order(str(wo_file))
    
    # Create execution result
    result = ExecutionResult(
        wo_id=wo.wo_id,
        status=WOStatus.COMPLETED,
        files_modified=["g/reports/test.md"],
        checksums={"g/reports/test.md": ("before_hash", "after_hash")},
        execution_time=1.5,
        errors=[],
        warnings=[]
    )
    
    # Write audit log
    log_path_str = write_audit_log(wo, result)
    log_path = Path(log_path_str)  # Function returns string, convert to Path
    
    assert log_path.exists(), "Audit log file should exist"
    
    # Read and verify content
    with open(log_path, 'r') as f:
        log_data = json.load(f)
    
    required_fields = [
        "wo_id",
        "status",
        "execution_time",
        "files_modified",
        "checksums",
        "errors",
        "warnings",
        "origin",
        "risk_level"
    ]
    
    for field in required_fields:
        assert field in log_data, f"Audit log should contain field: {field}"
    
    assert log_data["wo_id"] == "TEST-AUDIT-001", "WO ID should match"
    assert log_data["status"] == "COMPLETED", "Status should match"
    
    import shutil
    shutil.rmtree(test_dir)


def test_audit_log_location():
    """Test that audit log is written to correct location."""
    test_dir = Path(tempfile.mkdtemp())
    wo_file = test_dir / "test_wo.yaml"
    
    wo_data = {
        "wo_id": "TEST-AUDIT-002",
        "created_at": "2025-12-10T10:00:00+07:00",
        "origin": {"world": "BACKGROUND", "actor": "CLC"},
        "target_paths": ["g/reports/test.md"],
        "zone_summary": {"g/reports/test.md": "OPEN"},
        "risk_level": "LOW",
        "desired_state": "Test",
        "change_type": "ADD"
    }
    
    with open(wo_file, 'w') as f:
        yaml.dump(wo_data, f)
    
    wo = read_work_order(str(wo_file))
    
    result = ExecutionResult(
        wo_id=wo.wo_id,
        status=WOStatus.COMPLETED,
        files_modified=[],
        checksums={},
        execution_time=0.5,
        errors=[],
        warnings=[]
    )
    
    log_path_str = write_audit_log(wo, result)
    log_path = Path(log_path_str)  # Function returns string, convert to Path
    
    # Check that log is in expected location (g/logs/clc_execution/)
    assert "clc_execution" in str(log_path) or "logs" in str(log_path), "Audit log should be in logs directory"
    assert log_path.suffix == ".json", "Audit log should be JSON file"
    
    import shutil
    shutil.rmtree(test_dir)


if __name__ == "__main__":
    import unittest
    
    class TestAuditLog(unittest.TestCase):
        def test_required_fields(self):
            test_audit_log_contains_required_fields()
        
        def test_log_location(self):
            test_audit_log_location()
    
    unittest.main()

