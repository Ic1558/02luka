#!/usr/bin/env python3
"""
Test Router v5 CLS Auto-approve Conditions

Tests for check_cls_auto_approve_conditions() function covering:
- Actor must be CLS
- Zone must be LOCKED
- Path in Mission Scope whitelist
- Path not in blacklist
- Rollback strategy required
- Boss approved pattern required
"""

import sys
from pathlib import Path

# Add project root to path
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

from bridge.core.router_v5 import check_cls_auto_approve_conditions, route


def test_actor_must_be_cls():
    """Test that only CLS actor can auto-approve."""
    zone = "LOCKED"
    path = "g/reports/test.md"  # In whitelist
    
    # Non-CLS actors should not auto-approve
    for actor in ["Liam", "GMX", "Codex", "Boss"]:
        can_approve, conditions = check_cls_auto_approve_conditions(actor, zone, path)
        assert not can_approve, f"Actor {actor} should not auto-approve, got {can_approve}"
        assert not conditions.get("actor_is_cls", False), f"Actor {actor} should not have actor_is_cls=True"


def test_zone_must_be_locked():
    """Test that only LOCKED zone can auto-approve."""
    actor = "CLS"
    path = "g/reports/test.md"  # In whitelist
    
    # Non-LOCKED zones should not auto-approve
    for zone in ["OPEN", "DANGER"]:
        can_approve, conditions = check_cls_auto_approve_conditions(actor, zone, path)
        assert not can_approve, f"Zone {zone} should not auto-approve, got {can_approve}"
        assert not conditions.get("zone_is_locked", False), f"Zone {zone} should not have zone_is_locked=True"


def test_path_must_be_in_whitelist():
    """Test that path must be in Mission Scope whitelist."""
    actor = "CLS"
    zone = "LOCKED"
    
    # Whitelist paths
    whitelist_paths = [
        "bridge/templates/test.yaml",
        "g/reports/test.md",
        "tools/test.sh",
        "agents/test.py",
        "bridge/docs/test.md",
    ]
    
    for path in whitelist_paths:
        can_approve, conditions = check_cls_auto_approve_conditions(actor, zone, path, {
            "rollback_strategy": "git_revert",
            "boss_approved_pattern": True
        })
        assert conditions.get("path_in_whitelist", False), f"Path {path} should be in whitelist"


def test_path_must_not_be_in_blacklist():
    """Test that blacklist paths cannot auto-approve."""
    actor = "CLS"
    zone = "LOCKED"
    
    # Blacklist paths
    blacklist_paths = [
        "core/config.yaml",
        "bridge/core/router_v5.py",
        "bridge/handlers/test.py",
        "bridge/production/test.yaml",
        "g/docs/governance/test.md",
        "launchd/test.plist",
    ]
    
    for path in blacklist_paths:
        can_approve, conditions = check_cls_auto_approve_conditions(actor, zone, path, {
            "rollback_strategy": "git_revert",
            "boss_approved_pattern": True
        })
        assert not can_approve, f"Blacklist path {path} should not auto-approve, got {can_approve}"
        assert conditions.get("path_not_blacklisted", False) == False, f"Blacklist path {path} should have path_not_blacklisted=False"


def test_rollback_strategy_required():
    """Test that rollback strategy is required for auto-approve."""
    actor = "CLS"
    zone = "LOCKED"
    path = "g/reports/test.md"  # In whitelist
    
    # Without rollback strategy
    can_approve_no_rollback, _ = check_cls_auto_approve_conditions(actor, zone, path, {
        "boss_approved_pattern": True
    })
    assert not can_approve_no_rollback, "Should not auto-approve without rollback strategy"
    
    # With rollback strategy
    can_approve_with_rollback, conditions = check_cls_auto_approve_conditions(actor, zone, path, {
        "rollback_strategy": "git_revert",
        "boss_approved_pattern": True
    })
    assert conditions.get("rollback_strategy_exists", False), "Should have rollback_strategy_exists=True"


def test_boss_approved_pattern_required():
    """Test that boss approved pattern is required for auto-approve."""
    actor = "CLS"
    zone = "LOCKED"
    path = "g/reports/test.md"  # In whitelist
    
    # Without boss approved pattern
    can_approve_no_boss, _ = check_cls_auto_approve_conditions(actor, zone, path, {
        "rollback_strategy": "git_revert"
    })
    assert not can_approve_no_boss, "Should not auto-approve without boss approved pattern"
    
    # With boss approved pattern
    can_approve_with_boss, conditions = check_cls_auto_approve_conditions(actor, zone, path, {
        "rollback_strategy": "git_revert",
        "boss_approved_pattern": True
    })
    assert conditions.get("boss_approved_similar", False), "Should have boss_approved_similar=True"


def test_route_sets_rollback_required():
    """Test that route() sets rollback_required=True when auto-approve is allowed."""
    decision = route(
        trigger="cursor",
        actor="CLS",
        path="bridge/core/router.py",  # LOCKED zone (core/), in whitelist
        op="write",
        context={
            "rollback_strategy": "git_revert",
            "boss_approved_pattern": True
        }
    )
    
    assert decision.lane == "WARN", "Should be WARN lane for LOCKED zone"
    if decision.auto_approve_allowed:
        assert decision.rollback_required, "Should require rollback when auto-approve is allowed"


if __name__ == "__main__":
    import unittest
    
    class TestCLSAutoApprove(unittest.TestCase):
        def test_actor_must_be_cls(self):
            test_actor_must_be_cls()
        
        def test_zone_must_be_locked(self):
            test_zone_must_be_locked()
        
        def test_whitelist(self):
            test_path_must_be_in_whitelist()
        
        def test_blacklist(self):
            test_path_must_not_be_in_blacklist()
        
        def test_rollback_required(self):
            test_rollback_strategy_required()
        
        def test_boss_approved_required(self):
            test_boss_approved_pattern_required()
        
        def test_rollback_required_flag(self):
            test_route_sets_rollback_required()
    
    unittest.main()

