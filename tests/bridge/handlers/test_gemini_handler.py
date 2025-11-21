#!/usr/bin/env python3
"""
Tests for bridge/handlers/gemini_handler.py

Tests the public interface and behavior of GeminiHandler and handle_wo.
"""
from __future__ import annotations

import sys
from pathlib import Path
from unittest.mock import MagicMock, patch

# Add project root to path
REPO_ROOT = Path(__file__).resolve().parents[3]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

# Mock gemini_connector before importing to avoid dependency issues
import sys
from unittest.mock import MagicMock

# Create mock module
mock_gemini_connector = MagicMock()
mock_gemini_connector.run_gemini_task = MagicMock(return_value={"result": "mocked"})
sys.modules['g.connectors.gemini_connector'] = mock_gemini_connector

from bridge.handlers.gemini_handler import handle_wo, handle, GeminiHandler
from bridge.handlers.gemini_logic import (
    _normalize_payload,
    _build_task_spec,
    _check_overseer,
    _apply_decision_gate,
)


def test_normalize_payload():
    """Test payload normalization."""
    wo = {
        "task_type": "code_transform",
        "input": {
            "instructions": "Add comments",
            "target_files": ["test.py"],
            "command": "test command",
        },
        "command": "top-level command",
    }
    
    payload = _normalize_payload(wo)
    assert "instructions" in payload
    assert "target_files" in payload
    assert "command" in payload
    # Top-level command should take precedence
    assert payload["command"] == "top-level command"
    print("✅ test_normalize_payload passed")


def test_build_task_spec():
    """Test task_spec building."""
    payload = {
        "target_files": ["test.py"],
        "command": "ls -la",
        "context": {"description": "test"},
    }
    
    task_spec = _build_task_spec("code_transform", payload)
    assert task_spec["intent"] == "refactor"  # code_transform maps to refactor
    assert task_spec["target_files"] == ["test.py"]
    print("✅ test_build_task_spec passed")


def test_handle_compatibility_shim():
    """Test handle() compatibility shim."""
    wo = {"task_type": "code_transform", "input": {}}
    
    # Mock gemini_connector.run_gemini_task
    import bridge.handlers.gemini_logic as logic
    original_run = logic.gemini_connector.run_gemini_task
    logic.gemini_connector.run_gemini_task = MagicMock(return_value={"result": "test"})
    
    try:
        result = handle(wo)
        # Should call handle_wo and return a dict
        assert isinstance(result, dict)
        assert "ok" in result or "status" in result
    finally:
        logic.gemini_connector.run_gemini_task = original_run
    print("✅ test_handle_compatibility_shim passed")


def test_gemini_handler_class():
    """Test GeminiHandler class instantiation."""
    handler = GeminiHandler()
    assert handler.inbox.exists() or handler.inbox.parent.exists()
    assert handler.outbox.exists() or handler.outbox.parent.exists()
    print("✅ test_gemini_handler_class passed")


def test_overseer_integration():
    """Test that Overseer integration is preserved."""
    # Check that the logic module has overseer functions
    import bridge.handlers.gemini_logic as logic
    
    assert hasattr(logic, "_check_overseer")
    assert hasattr(logic, "_apply_decision_gate")
    assert hasattr(logic, "MARY_ROUTER_AVAILABLE")
    print("✅ test_overseer_integration passed")


def test_error_message_propagation():
    """Test that error messages from handle_wo are correctly propagated to result files."""
    import tempfile
    import yaml
    
    # Create a temporary directory for testing
    with tempfile.TemporaryDirectory() as tmpdir:
        handler = GeminiHandler(base_dir=Path(tmpdir))
        
        # Create a test WO file
        wo_file = handler.inbox / "test_wo.yaml"
        wo_file.parent.mkdir(parents=True, exist_ok=True)
        wo_file.write_text("wo_id: test_wo\ntask_type: code_transform\ninput: {}\n")
        
        # Mock handle_wo to return a specific error
        with patch("bridge.handlers.gemini_handler.handle_wo") as mock_handle:
            mock_handle.return_value = {
                "ok": False,
                "status": "BLOCKED",
                "error": "A specific test error",
            }
            
            # Process the work order
            result = handler.process_work_order(wo_file)
            assert result is False, "Should return False for failed WO"
            
            # Check that the error result file was created
            result_file = handler.outbox / "test_wo_result.yaml"
            assert result_file.exists(), "Error result file should exist"
            
            # Read and verify the error message
            with result_file.open("r") as f:
                result_data = yaml.safe_load(f)
            
            assert result_data["status"] == "failed", "Status should be 'failed'"
            assert "A specific test error" in result_data["error"], "Error message should be propagated"
            assert "BLOCKED" in result_data["error"], "Status should be included in error"
            
    print("✅ test_error_message_propagation passed")


def test_error_message_fallback():
    """Test error message fallback when only 'reason' is present."""
    import tempfile
    import yaml
    
    with tempfile.TemporaryDirectory() as tmpdir:
        handler = GeminiHandler(base_dir=Path(tmpdir))
        
        wo_file = handler.inbox / "test_wo2.yaml"
        wo_file.parent.mkdir(parents=True, exist_ok=True)
        wo_file.write_text("wo_id: test_wo2\ntask_type: code_transform\ninput: {}\n")
        
        with patch("bridge.handlers.gemini_handler.handle_wo") as mock_handle:
            mock_handle.return_value = {
                "ok": False,
                "status": "REVIEW_REQUIRED",
                "reason": "GM advisor review needed for this task",
            }
            
            result = handler.process_work_order(wo_file)
            assert result is False
            
            result_file = handler.outbox / "test_wo2_result.yaml"
            assert result_file.exists()
            
            with result_file.open("r") as f:
                result_data = yaml.safe_load(f)
            
            assert "GM advisor review needed" in result_data["error"]
            assert "REVIEW_REQUIRED" in result_data["error"]
            
    print("✅ test_error_message_fallback passed")


def test_error_message_default():
    """Test error message default when neither 'error' nor 'reason' is present."""
    import tempfile
    import yaml
    
    with tempfile.TemporaryDirectory() as tmpdir:
        handler = GeminiHandler(base_dir=Path(tmpdir))
        
        wo_file = handler.inbox / "test_wo3.yaml"
        wo_file.parent.mkdir(parents=True, exist_ok=True)
        wo_file.write_text("wo_id: test_wo3\ntask_type: code_transform\ninput: {}\n")
        
        with patch("bridge.handlers.gemini_handler.handle_wo") as mock_handle:
            mock_handle.return_value = {
                "ok": False,
            }
            
            result = handler.process_work_order(wo_file)
            assert result is False
            
            result_file = handler.outbox / "test_wo3_result.yaml"
            assert result_file.exists()
            
            with result_file.open("r") as f:
                result_data = yaml.safe_load(f)
            
            assert "no reason provided" in result_data["error"]
            assert "FAILED" in result_data["error"]
            
    print("✅ test_error_message_default passed")


if __name__ == "__main__":
    print("Running Gemini Handler Tests")
    print("=" * 60)
    
    try:
        test_normalize_payload()
        test_build_task_spec()
        test_handle_compatibility_shim()
        test_gemini_handler_class()
        test_overseer_integration()
        test_error_message_propagation()
        test_error_message_fallback()
        test_error_message_default()
        
        print("\n" + "=" * 60)
        print("✅ All tests passed!")
        sys.exit(0)
    except Exception as e:
        print(f"\n❌ Test failed: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
