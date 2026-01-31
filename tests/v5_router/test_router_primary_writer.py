#!/usr/bin/env python3
"""
Test Router v5 Primary Writer Determination

Tests for determine_primary_writer() function covering:
- BACKGROUND world → CLC
- CLI world → actor (if allowed)
- BLOCKED lane → None
- Planner/Router actors → None
"""

import sys
from pathlib import Path

# Add project root to path
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

from bridge.core.router_v5 import determine_primary_writer, resolve_lane


def test_background_world_returns_clc():
    """Test that BACKGROUND world always returns CLC as primary writer."""
    world = "BACKGROUND"
    zone = "OPEN"  # Any zone
    lane = "STRICT"
    
    # Any actor in BACKGROUND should result in CLC
    for actor in ["CLC", "LPE", "Cron", "Watchdog"]:
        writer = determine_primary_writer(world, zone, lane, actor)
        assert writer == "CLC", f"BACKGROUND world with actor {actor} should return CLC, got {writer}"


def test_cli_world_allowed_actors():
    """Test that CLI world returns actor if actor is in allowed list."""
    world = "CLI"
    zone = "OPEN"
    lane = "FAST"
    
    allowed_actors = ["Boss", "CLS", "Liam", "GMX", "Codex", "Gemini", "LAC"]
    
    for actor in allowed_actors:
        writer = determine_primary_writer(world, zone, lane, actor)
        assert writer == actor, f"CLI world with allowed actor {actor} should return {actor}, got {writer}"


def test_cli_world_planner_actors():
    """Test that planner actors (GG, GM) cannot write."""
    world = "CLI"
    zone = "OPEN"
    lane = "FAST"
    
    planner_actors = ["GG", "GM"]
    
    for actor in planner_actors:
        writer = determine_primary_writer(world, zone, lane, actor)
        assert writer is None, f"Planner actor {actor} should return None, got {writer}"


def test_cli_world_router_actor():
    """Test that router actor (Mary) cannot write."""
    world = "CLI"
    zone = "OPEN"
    lane = "FAST"
    actor = "Mary"
    
    writer = determine_primary_writer(world, zone, lane, actor)
    assert writer is None, f"Router actor {actor} should return None, got {writer}"


def test_cli_world_background_actors():
    """Test that background actors (CLC, LPE) cannot write in CLI world."""
    world = "CLI"
    zone = "OPEN"
    lane = "FAST"
    
    bg_actors = ["CLC", "LPE"]
    
    for actor in bg_actors:
        writer = determine_primary_writer(world, zone, lane, actor)
        assert writer is None, f"Background actor {actor} in CLI world should return None, got {writer}"


def test_blocked_lane_returns_none():
    """Test that BLOCKED lane always returns None."""
    world = "CLI"
    zone = "DANGER"
    lane = "BLOCKED"
    
    # Any actor should result in None for BLOCKED
    for actor in ["CLS", "Boss", "CLC"]:
        writer = determine_primary_writer(world, zone, lane, actor)
        assert writer is None, f"BLOCKED lane with actor {actor} should return None, got {writer}"


if __name__ == "__main__":
    import unittest
    
    class TestPrimaryWriter(unittest.TestCase):
        def test_background_clc(self):
            test_background_world_returns_clc()
        
        def test_cli_allowed(self):
            test_cli_world_allowed_actors()
        
        def test_cli_planners(self):
            test_cli_world_planner_actors()
        
        def test_cli_router(self):
            test_cli_world_router_actor()
        
        def test_cli_background(self):
            test_cli_world_background_actors()
        
        def test_blocked(self):
            test_blocked_lane_returns_none()
    
    unittest.main()

