#!/usr/bin/env python3
"""
Test Router v5 World Resolution

Tests for resolve_world() function covering:
- CLI world triggers
- Background world triggers
- Context-based fallback
- Unknown trigger default
"""

import sys
from pathlib import Path

# Add project root to path
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

from bridge.core.router_v5 import resolve_world


def test_cli_world_triggers():
    """Test that CLI triggers resolve to CLI world."""
    cli_triggers = [
        "human",
        "boss",
        "cursor",
        "terminal",
        "antigravity",
        "gmx",
        "codex",
        "gemini",
        "lac",
        "cls",
        "liam"
    ]
    
    for trigger in cli_triggers:
        world = resolve_world(trigger)
        assert world == "CLI", f"Trigger '{trigger}' should resolve to CLI, got {world}"


def test_background_world_triggers():
    """Test that background triggers resolve to BACKGROUND world."""
    bg_triggers = [
        "cron",
        "launchd",
        "daemon",
        "queue",
        "worker",
        "watchdog",
        "scheduler",
        "background"
    ]
    
    for trigger in bg_triggers:
        world = resolve_world(trigger)
        assert world == "BACKGROUND", f"Trigger '{trigger}' should resolve to BACKGROUND, got {world}"


def test_context_wo_id_fallback():
    """Test that context with wo_id falls back to BACKGROUND."""
    context = {"wo_id": "WO-TEST-001"}
    world = resolve_world("unknown_trigger", context)
    assert world == "BACKGROUND", f"Unknown trigger with wo_id should resolve to BACKGROUND, got {world}"


def test_unknown_trigger_default():
    """Test that unknown trigger without context raises ValueError (strict validation)."""
    import pytest
    with pytest.raises(ValueError):
        resolve_world("unknown_trigger")


def test_case_insensitive():
    """Test that trigger matching is case-insensitive."""
    assert resolve_world("CURSOR") == "CLI"
    assert resolve_world("Cursor") == "CLI"
    assert resolve_world("CRON") == "BACKGROUND"
    assert resolve_world("Cron") == "BACKGROUND"


if __name__ == "__main__":
    import unittest
    
    class TestWorldResolution(unittest.TestCase):
        def test_cli_triggers(self):
            test_cli_world_triggers()
        
        def test_background_triggers(self):
            test_background_world_triggers()
        
        def test_context_wo_id(self):
            test_context_wo_id_fallback()
        
        def test_unknown_default(self):
            test_unknown_trigger_default()
        
        def test_case_insensitive(self):
            test_case_insensitive()
    
    unittest.main()

