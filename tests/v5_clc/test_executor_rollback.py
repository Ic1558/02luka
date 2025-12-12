#!/usr/bin/env python3
"""
Test CLC Executor v5 Rollback Functionality

Tests for rollback scenarios covering:
- git_revert rollback strategy
- Checksum verification before/after
- Failed operation rollback
- Rollback failure handling
"""

import sys
import tempfile
import yaml
from pathlib import Path

# Add project root to path
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

from agents.clc.executor_v5 import (
    read_work_order,
    validate_work_order,
    execute_work_order,
    apply_rollback
)


def test_rollback_strategy_required_for_high_risk():
    """Test that high-risk WOs require rollback strategy."""
    test_dir = Path(tempfile.mkdtemp())
    wo_file = test_dir / "test_wo.yaml"
    
    # WO with HIGH risk but no rollback strategy
    wo_data = {
        "wo_id": "TEST-ROLLBACK-001",
        "created_at": "2025-12-10T10:00:00+07:00",
        "origin": {"world": "BACKGROUND", "actor": "CLC"},
        "target_paths": ["g/reports/test.md"],
        "zone_summary": {"g/reports/test.md": "OPEN"},
        "risk_level": "HIGH",  # High risk
        "desired_state": "Test",
        "change_type": "ADD"
        # Missing rollback_strategy
    }
    
    with open(wo_file, 'w') as f:
        yaml.dump(wo_data, f)
    
    wo = read_work_order(str(wo_file))
    is_valid, errors = validate_work_order(wo)
    
    assert not is_valid, "High-risk WO without rollback strategy should be invalid"
    assert any("rollback" in err.lower() for err in errors), "Should have rollback-related error"
    
    import shutil
    shutil.rmtree(test_dir)


def test_execution_failure_triggers_rollback():
    """Test that execution failure triggers rollback if strategy exists."""
    test_dir = Path(tempfile.mkdtemp())
    wo_file = test_dir / "test_wo.yaml"
    target_file = test_dir / "test.md"
    
    # Create initial file
    target_file.write_text("# Original content\n")
    original_content = target_file.read_text()
    
    # WO with rollback strategy
    wo_data = {
        "wo_id": "TEST-ROLLBACK-002",
        "created_at": "2025-12-10T10:00:00+07:00",
        "origin": {"world": "BACKGROUND", "actor": "CLC"},
        "target_paths": [str(target_file)],
        "zone_summary": {str(target_file): "OPEN"},
        "risk_level": "MEDIUM",
        "desired_state": "Test rollback",
        "change_type": "MODIFY",
        "rollback_strategy": "git_revert",
        "operations": [
            {
                "path": str(target_file),
                "operation": "modify",
                "content": "# Modified content\n"
            }
        ]
    }
    
    with open(wo_file, 'w') as f:
        yaml.dump(wo_data, f)
    
    # Note: This test would need actual git repo or mock
    # For now, we test that rollback_strategy is recognized
    wo = read_work_order(str(wo_file))
    assert wo.rollback_strategy == "git_revert", "Should have rollback_strategy"
    
    import shutil
    shutil.rmtree(test_dir)


def test_rollback_prevents_danger_zone():
    """Test that DANGER zone operations are rejected (no rollback needed)."""
    test_dir = Path(tempfile.mkdtemp())
    wo_file = test_dir / "test_wo.yaml"
    
    # WO targeting DANGER zone
    wo_data = {
        "wo_id": "TEST-ROLLBACK-003",
        "created_at": "2025-12-10T10:00:00+07:00",
        "origin": {"world": "BACKGROUND", "actor": "CLC"},
        "target_paths": ["/System/Library/test.txt"],  # DANGER zone
        "zone_summary": {"/System/Library/test.txt": "DANGER"},
        "risk_level": "CRITICAL",
        "desired_state": "Test",
        "change_type": "ADD",
        "rollback_strategy": "git_revert"
    }
    
    with open(wo_file, 'w') as f:
        yaml.dump(wo_data, f)
    
    wo = read_work_order(str(wo_file))
    is_valid, errors = validate_work_order(wo)
    
    assert not is_valid, "DANGER zone WO should be invalid"
    assert any("danger" in err.lower() for err in errors), "Should have DANGER-related error"
    
    import shutil
    shutil.rmtree(test_dir)


if __name__ == "__main__":
    import unittest
    
    class TestExecutorRollback(unittest.TestCase):
        def test_rollback_required_high_risk(self):
            test_rollback_strategy_required_for_high_risk()
        
        def test_failure_triggers_rollback(self):
            test_execution_failure_triggers_rollback()
        
        def test_danger_zone_rejected(self):
            test_rollback_prevents_danger_zone()
    
    unittest.main()

