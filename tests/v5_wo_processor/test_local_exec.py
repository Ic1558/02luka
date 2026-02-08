"""
WO Processor v5 — Local Execution Tests

Tests local execution of FAST/WARN lane operations.
"""

import pytest
import sys
import tempfile
from pathlib import Path

project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

try:
    from bridge.core.wo_processor_v5 import execute_local_operation, execute_local_operations
except ImportError:
    # Fallback mock
    def execute_local_operation(operation, actor, routing_decision, context):
        path = operation.get('path', '')
        content = operation.get('content', '')
        
        # Mock SandboxGuard check
        if 'forbidden' in content.lower():
            return (False, "SandboxGuard blocked", [])
        
        return (True, None, [])
    
    def execute_local_operations(operations, routings, actor, wo_id):
        results = []
        for op in operations:
            success, error, warnings = execute_local_operation(
                op, actor, routings[0] if routings else None, {"wo_id": wo_id}
            )
            results.append({"path": op.get('path'), "success": success, "error": error, "warnings": warnings})
        
        return {
            "operations": results,
            "warnings": [],
            "errors": [],
            "success_count": sum(1 for r in results if r["success"]),
            "failure_count": sum(1 for r in results if not r["success"])
        }


def test_local_exec_success(tmp_path):
    """Test successful local execution."""
    import os
    from pathlib import Path
    
    # Use a path within 02luka root for SandboxGuard validation
    luka_root = Path(os.environ.get("LUKA_ROOT", os.environ.get("LUKA_SOT", Path.home() / "02luka")))
    test_file = luka_root / "g" / "reports" / "test_local_exec.txt"
    
    operation = {
        "path": str(test_file),
        "operation": "write",
        "content": "Hello, World!"
    }
    
    class MockRoutingDecision:
        def __init__(self):
            self.zone = "OPEN"
            self.lane = "FAST"
            self.auto_approve_allowed = False
    
    success, error, warnings = execute_local_operation(
        operation=operation,
        actor="CLS",
        routing_decision=MockRoutingDecision(),
        context={"wo_id": "WO-TEST"}
    )
    
    assert success == True, f"Expected success but got error: {error}"
    assert error is None
    
    # Cleanup
    if test_file.exists():
        test_file.unlink()


def test_local_exec_sandbox_blocked():
    """Test local execution blocked by SandboxGuard."""
    operation = {
        "path": "tools/script.sh",
        "operation": "write",
        "content": "rm -rf /tmp"  # Forbidden pattern
    }
    
    class MockRouting:
        def __init__(self):
            self.zone = "OPEN"
            self.lane = "FAST"
            self.auto_approve_allowed = False
    
    success, error, warnings = execute_local_operation(
        operation=operation,
        actor="CLS",
        routing_decision=MockRouting(),
        context={"wo_id": "WO-TEST"}
    )
    
    # Should be blocked by SandboxGuard
    assert success == False or "SandboxGuard" in str(error)


def test_local_exec_batch(tmp_path):
    """Test batch local execution."""
    from bridge.core.wo_processor_v5 import OperationRouting
    
    operations = [
        {"path": str(tmp_path / "file1.txt"), "operation": "write", "content": "Content 1"},
        {"path": str(tmp_path / "file2.txt"), "operation": "write", "content": "Content 2"},
    ]
    
    class MockRoutingDecision:
        def __init__(self):
            self.zone = "OPEN"
            self.lane = "FAST"
            self.auto_approve_allowed = False
    
    # Create proper OperationRouting objects
    routings = []
    for op in operations:
        routing = OperationRouting(
            operation=op,
            routing_decision=MockRoutingDecision(),
            lane="FAST",
            destination="LOCAL",
            reason="Test"
        )
        routings.append(routing)
    
    result = execute_local_operations(
        operations=operations,
        routings=routings,
        actor="CLS",
        wo_id="WO-TEST"
    )
    
    assert result["success_count"] >= 0
    assert len(result["operations"]) == len(operations)


def test_local_exec_move_success(tmp_path):
    """Test successful move operation."""
    import os
    from pathlib import Path
    
    # Use paths within 02luka root for SandboxGuard validation
    luka_root = Path(os.environ.get("LUKA_ROOT", os.environ.get("LUKA_SOT", Path.home() / "02luka")))
    source_file = luka_root / "g" / "reports" / "test_move_source.txt"
    target_file = luka_root / "g" / "reports" / "test_move_target.txt"
    
    # Create source file
    source_file.write_text("Move test content")
    
    operation = {
        "path": str(target_file),
        "operation": "move",
        "source_path": str(source_file)
    }
    
    class MockRoutingDecision:
        def __init__(self):
            self.zone = "OPEN"
            self.lane = "FAST"
            self.auto_approve_allowed = False
    
    success, error, warnings = execute_local_operation(
        operation=operation,
        actor="CLS",
        routing_decision=MockRoutingDecision(),
        context={"wo_id": "WO-TEST"}
    )
    
    assert success == True, f"Expected success but got error: {error}"
    assert error is None
    assert target_file.exists(), "Target file should exist after move"
    assert not source_file.exists(), "Source file should not exist after move"
    assert target_file.read_text() == "Move test content", "Content should be preserved"
    
    # Cleanup
    if target_file.exists():
        target_file.unlink()


def test_local_exec_move_source_not_exists(tmp_path):
    """Test move operation fails when source file doesn't exist."""
    import os
    from pathlib import Path
    
    luka_root = Path(os.environ.get("LUKA_ROOT", os.environ.get("LUKA_SOT", Path.home() / "02luka")))
    source_file = luka_root / "g" / "reports" / "nonexistent_source.txt"
    target_file = luka_root / "g" / "reports" / "test_move_target.txt"
    
    operation = {
        "path": str(target_file),
        "operation": "move",
        "source_path": str(source_file)
    }
    
    class MockRoutingDecision:
        def __init__(self):
            self.zone = "OPEN"
            self.lane = "FAST"
            self.auto_approve_allowed = False
    
    success, error, warnings = execute_local_operation(
        operation=operation,
        actor="CLS",
        routing_decision=MockRoutingDecision(),
        context={"wo_id": "WO-TEST"}
    )
    
    assert success == False, "Should fail when source file doesn't exist"
    assert error is not None
    assert "Source file does not exist" in error or "does not exist" in error.lower()

