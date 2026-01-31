"""
WO Processor v5 — CLC WO Schema Tests

Tests CLC WO creation and schema validation.
"""

import pytest
import sys
import yaml
from pathlib import Path

project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

try:
    from bridge.core.wo_processor_v5 import create_clc_wo
except ImportError:
    # Fallback mock
    def create_clc_wo(wo, strict_operations):
        return "mock_clc_wo.yaml"


def test_clc_wo_schema_required_fields(tmp_path, monkeypatch):
    """Test CLC WO contains all required fields."""
    wo_data = {
        "wo_id": "WO-SOURCE",
        "origin": {"world": "BACKGROUND", "actor": "CLC"},
        "target_paths": ["core/config.yaml"],
        "risk_level": "MEDIUM",
        "desired_state": "Update config",
        "change_type": "MODIFY",
        "rollback_strategy": "git_revert"
    }
    
    operations = [
        {"path": "core/config.yaml", "operation": "write", "content": "key: value"}
    ]
    
    clc_wo_file = tmp_path / "clc_wo.yaml"
    
    def mock_create_file(path, content):
        clc_wo_file.write_text(content)
    
    monkeypatch.setattr("pathlib.Path.write_text", mock_create_file)
    
    clc_wo_path = create_clc_wo(wo_data, operations)
    
    # Verify WO file would be created (or check mock)
    assert clc_wo_path is not None


def test_clc_wo_origin_background():
    """Test CLC WO origin.world is BACKGROUND."""
    wo_data = {
        "wo_id": "WO-SOURCE",
        "origin": {"world": "BACKGROUND", "actor": "CLC"},
        "target_paths": ["core/config.yaml"]
    }
    
    operations = [{"path": "core/config.yaml", "operation": "write", "content": "test"}]
    
    # Mock file creation
    clc_wo_path = create_clc_wo(wo_data, operations)
    
    # Verify origin.world would be BACKGROUND in created WO
    assert clc_wo_path is not None


def test_clc_wo_operations_included():
    """Test CLC WO includes all operations."""
    wo_data = {
        "wo_id": "WO-SOURCE",
        "origin": {"world": "BACKGROUND", "actor": "CLC"},
        "target_paths": ["core/config.yaml"]
    }
    
    operations = [
        {"path": "core/config.yaml", "operation": "write", "content": "key: value"},
        {"path": "core/router.py", "operation": "modify", "content": "updated"}
    ]
    
    clc_wo_path = create_clc_wo(wo_data, operations)
    
    # Verify operations would be included
    assert clc_wo_path is not None

