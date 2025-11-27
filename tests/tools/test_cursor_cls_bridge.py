"""
Unit tests for CLS Cursor Bridge utilities.
"""

import json
import os
import tempfile
import time
from pathlib import Path

import pytest

from tools.cursor_cls_bridge.config import get_base_dir, get_inbox_path, get_outbox_path
from tools.cursor_cls_bridge.wo_builder import (
    build_work_order,
    generate_wo_id,
    detect_routing_hint,
    validate_wo_schema,
)
from tools.cursor_cls_bridge.io_utils import (
    drop_wo_to_inbox,
    poll_for_result,
    format_result_summary,
    format_timeout_message,
)


class TestWOBuilder:
    def test_generate_wo_id(self):
        wo_id = generate_wo_id()
        assert wo_id.startswith("WO-CLS-")
        assert len(wo_id) > 15  # Should have timestamp + suffix
    
    def test_detect_routing_hint_default(self):
        assert detect_routing_hint("fix this") == "oss"
    
    def test_detect_routing_hint_gmx(self):
        assert detect_routing_hint("use gmx to fix") == "gmxcli"
        assert detect_routing_hint("gmxcli analyze") == "gmxcli"
    
    def test_detect_routing_hint_gptdeep(self):
        assert detect_routing_hint("use gptdeep") == "gptdeep"
        assert detect_routing_hint("deep analysis") == "gptdeep"
    
    def test_build_work_order_basic(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            base_dir = Path(tmpdir)
            wo = build_work_order(
                command_text="Fix this file",
                base_dir=base_dir,
            )
            
            assert "wo_id" in wo
            assert wo["wo_id"].startswith("WO-CLS-")
            assert wo["objective"] == "Fix this file"
            assert wo["routing_hint"] == "oss"
            assert wo["priority"] == "P1"
            assert wo["self_apply"] is True
            assert wo["complexity"] == "simple"
            assert wo["requires_paid_lane"] is False
            assert wo["source"] == "cursor_cls_wrapper"
            assert "context" in wo
    
    def test_build_work_order_with_file(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            base_dir = Path(tmpdir)
            wo = build_work_order(
                command_text="Refactor this",
                base_dir=base_dir,
                file_path="g/src/test.py",
                selection_start=10,
                selection_end=20,
            )
            
            assert wo["context"]["file_path"] == "g/src/test.py"
            assert wo["context"]["selection"]["start_line"] == 10
            assert wo["context"]["selection"]["end_line"] == 20
    
    def test_validate_wo_schema_valid(self):
        wo = {
            "wo_id": "WO-CLS-20251128-001",
            "objective": "Test",
            "routing_hint": "oss",
            "priority": "P1",
        }
        assert validate_wo_schema(wo) is True
    
    def test_validate_wo_schema_missing_field(self):
        wo = {
            "wo_id": "WO-CLS-20251128-001",
            "objective": "Test",
            # Missing routing_hint
            "priority": "P1",
        }
        with pytest.raises(ValueError, match="Missing required field"):
            validate_wo_schema(wo)
    
    def test_validate_wo_schema_invalid_routing(self):
        wo = {
            "wo_id": "WO-CLS-20251128-001",
            "objective": "Test",
            "routing_hint": "invalid",
            "priority": "P1",
        }
        with pytest.raises(ValueError, match="Invalid routing_hint"):
            validate_wo_schema(wo)


class TestIOUtils:
    def test_drop_wo_to_inbox(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            inbox_path = Path(tmpdir)
            wo = {
                "wo_id": "WO-CLS-TEST-001",
                "objective": "Test",
                "routing_hint": "oss",
                "priority": "P1",
            }
            
            wo_file = drop_wo_to_inbox(wo, inbox_path)
            
            assert wo_file.exists()
            assert wo_file.name == "WO-CLS-TEST-001.json"
            
            # Verify content
            with wo_file.open("r") as f:
                loaded = json.load(f)
                assert loaded["wo_id"] == "WO-CLS-TEST-001"
    
    def test_poll_for_result_found(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            outbox_path = Path(tmpdir)
            wo_id = "WO-CLS-TEST-001"
            
            # Create result file
            result = {
                "wo_id": wo_id,
                "status": "success",
                "files_touched": ["test.py"],
            }
            result_file = outbox_path / f"{wo_id}-RESULT.json"
            with result_file.open("w") as f:
                json.dump(result, f)
            
            # Poll should find it immediately
            found = poll_for_result(wo_id, outbox_path, timeout_seconds=5)
            assert found is not None
            assert found["status"] == "success"
    
    def test_poll_for_result_timeout(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            outbox_path = Path(tmpdir)
            wo_id = "WO-CLS-TEST-002"
            
            # No result file - should timeout
            found = poll_for_result(wo_id, outbox_path, timeout_seconds=1, poll_interval=0.1)
            assert found is None
    
    def test_format_result_summary(self):
        result = {
            "wo_id": "WO-CLS-TEST-001",
            "status": "success",
            "files_touched": ["file1.py", "file2.py"],
            "merge_type": "DIRECT",
            "used_clc": False,
            "used_paid": False,
        }
        
        summary = format_result_summary(result)
        assert "WO-CLS-TEST-001" in summary
        assert "success" in summary
        assert "file1.py" in summary
        assert "DIRECT" in summary
    
    def test_format_timeout_message(self):
        wo_id = "WO-CLS-TEST-001"
        outbox_path = Path("/tmp/outbox")
        
        message = format_timeout_message(wo_id, outbox_path)
        assert wo_id in message
        assert "still running" in message.lower()
        assert str(outbox_path) in message

