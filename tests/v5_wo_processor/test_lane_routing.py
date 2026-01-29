"""
WO Processor v5 — Lane-Based Routing Tests

Tests lane-based routing logic:
- STRICT → CLC
- FAST → Local execution
- WARN → Local (if auto-approve) or CLC
- BLOCKED → Reject
"""

import pytest
import sys
import yaml
from pathlib import Path

project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

try:
    from bridge.core.wo_processor_v5 import (
        process_wo_with_lane_routing,
        route_operations_by_lane,
        ProcessingStatus
    )
except ImportError:
    # Fallback mock
    class ProcessingStatus:
        COMPLETED = "COMPLETED"
        FAILED = "FAILED"
        REJECTED = "REJECTED"
    
    def route_operations_by_lane(wo, operations):
        # Mock routing
        routings = []
        for op in operations:
            path = op.get('path', '')
            if 'core/' in path or 'bridge/core/' in path:
                lane = "STRICT"
                destination = "CLC"
            elif 'apps/' in path or 'tools/' in path:
                lane = "FAST"
                destination = "LOCAL"
            else:
                lane = "BLOCKED"
                destination = "REJECTED"
            
            class MockRouting:
                def __init__(self):
                    self.operation = op
                    self.lane = lane
                    self.destination = destination
            
            routings.append(MockRouting())
        
        return (routings, [])
    
    def process_wo_with_lane_routing(wo_path):
        class MockResult:
            def __init__(self):
                self.wo_id = "WO-TEST"
                self.status = ProcessingStatus.COMPLETED
                self.strict_operations = []
                self.local_operations = []
                self.rejected_operations = []
                self.clc_wo_path = None
                self.errors = []
                self.warnings = []
        
        return MockResult()


def test_wo_processor_strict_to_clc(tmp_path, monkeypatch):
    """Test STRICT lane operations routed to CLC."""
    wo_data = {
        "wo_id": "WO-TEST-STRICT",
        "created_at": "2025-12-10T10:00:00Z",
        "origin": {"trigger": "background", "actor": "CLC"},
        "target_paths": ["core/config.yaml"],
        "operations": [
            {
                "path": "core/config.yaml",
                "operation": "write",
                "content": "key: value"
            }
        ]
    }
    
    wo_file = tmp_path / "WO-TEST-STRICT.yaml"
    wo_file.write_text(yaml.dump(wo_data))
    
    clc_wo_paths = []
    
    def mock_create_clc_wo(wo, ops):
        clc_wo_paths.append("mock_clc_wo.yaml")
        return "mock_clc_wo.yaml"
    
    monkeypatch.setattr("bridge.core.wo_processor_v5.create_clc_wo", mock_create_clc_wo)
    
    result = process_wo_with_lane_routing(str(wo_file))
    
    assert len(result.strict_operations) > 0 or result.clc_wo_path is not None
    assert result.status in [ProcessingStatus.COMPLETED, ProcessingStatus.FAILED]


def test_wo_processor_fast_local(tmp_path, monkeypatch):
    """Test FAST lane operations executed locally."""
    wo_data = {
        "wo_id": "WO-TEST-FAST",
        "created_at": "2025-12-10T10:00:00Z",
        "origin": {"trigger": "cursor", "actor": "CLS"},
        "target_paths": ["apps/myapp/main.py"],
        "operations": [
            {
                "path": "apps/myapp/main.py",
                "operation": "write",
                "content": "print('hello')"
            }
        ]
    }
    
    wo_file = tmp_path / "WO-TEST-FAST.yaml"
    wo_file.write_text(yaml.dump(wo_data))
    
    local_executions = []
    
    def mock_execute_local(ops, routings, actor, wo_id):
        local_executions.append({"count": len(ops)})
        return {"operations": [], "warnings": [], "errors": [], "success_count": 1, "failure_count": 0}
    
    monkeypatch.setattr("bridge.core.wo_processor_v5.execute_local_operations", mock_execute_local)
    
    result = process_wo_with_lane_routing(str(wo_file))
    
    assert len(result.local_operations) > 0 or len(local_executions) > 0
    assert result.clc_wo_path is None  # Should NOT go to CLC


def test_wo_processor_blocked_rejected(tmp_path):
    """Test BLOCKED lane operations rejected."""
    wo_data = {
        "wo_id": "WO-TEST-BLOCKED",
        "created_at": "2025-12-10T10:00:00Z",
        "origin": {"trigger": "cursor", "actor": "CLS"},
        "target_paths": ["/etc/hosts"],
        "operations": [
            {
                "path": "/etc/hosts",
                "operation": "write",
                "content": "127.0.0.1 test"
            }
        ]
    }
    
    wo_file = tmp_path / "WO-TEST-BLOCKED.yaml"
    wo_file.write_text(yaml.dump(wo_data))
    
    result = process_wo_with_lane_routing(str(wo_file))
    
    assert len(result.rejected_operations) > 0 or result.status == ProcessingStatus.REJECTED


def test_wo_processor_warn_auto_approve_local(tmp_path, monkeypatch):
    """Test WARN lane with auto-approve executed locally."""
    wo_data = {
        "wo_id": "WO-TEST-WARN",
        "created_at": "2025-12-10T10:00:00Z",
        "origin": {"trigger": "cursor", "actor": "CLS"},
        "target_paths": ["bridge/templates/email.html"],
        "operations": [
            {
                "path": "bridge/templates/email.html",
                "operation": "write",
                "content": "<html></html>"
            }
        ]
    }
    
    wo_file = tmp_path / "WO-TEST-WARN.yaml"
    wo_file.write_text(yaml.dump(wo_data))
    
    local_executions = []
    
    def mock_execute_local(ops, routings, actor, wo_id):
        local_executions.append({"count": len(ops)})
        return {"operations": [], "warnings": [], "errors": [], "success_count": 1, "failure_count": 0}
    
    monkeypatch.setattr("bridge.core.wo_processor_v5.execute_local_operations", mock_execute_local)
    
    result = process_wo_with_lane_routing(str(wo_file))
    
    # Should execute locally if auto-approve, or go to CLC if not
    assert len(result.local_operations) > 0 or len(result.strict_operations) > 0


def test_wo_processor_mixed_lanes(tmp_path, monkeypatch):
    """Test WO with mixed lanes (some STRICT, some FAST)."""
    wo_data = {
        "wo_id": "WO-TEST-MIXED",
        "created_at": "2025-12-10T10:00:00Z",
        "origin": {"trigger": "cursor", "actor": "CLS"},
        "target_paths": ["apps/main.py", "core/config.yaml"],
        "operations": [
            {"path": "apps/main.py", "operation": "write", "content": "print('hello')"},
            {"path": "core/config.yaml", "operation": "write", "content": "key: value"}
        ]
    }
    
    wo_file = tmp_path / "WO-TEST-MIXED.yaml"
    wo_file.write_text(yaml.dump(wo_data))
    
    clc_wo_paths = []
    local_executions = []
    
    def mock_create_clc_wo(wo, ops):
        clc_wo_paths.append("mock_clc_wo.yaml")
        return "mock_clc_wo.yaml"
    
    def mock_execute_local(ops, routings, actor, wo_id):
        local_executions.append({"count": len(ops)})
        return {"operations": [], "warnings": [], "errors": [], "success_count": len(ops), "failure_count": 0}
    
    monkeypatch.setattr("bridge.core.wo_processor_v5.create_clc_wo", mock_create_clc_wo)
    monkeypatch.setattr("bridge.core.wo_processor_v5.execute_local_operations", mock_execute_local)
    
    result = process_wo_with_lane_routing(str(wo_file))
    
    # Should have both STRICT and FAST operations
    assert (len(result.strict_operations) > 0 and len(result.local_operations) > 0) or \
           (len(clc_wo_paths) > 0 and len(local_executions) > 0)

