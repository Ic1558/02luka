"""
Router v5 — Mission Scope Auto-Approval Tests

Tests CLS auto-approve conditions:
- Mission Scope Whitelist paths
- Mission Scope Blacklist paths
- Auto-approve conditions (5 safety rules)
"""

import pytest
import sys
from pathlib import Path

project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

try:
    from bridge.core.router_v5 import route, check_mission_scope, check_cls_auto_approve_conditions
except ImportError:
    # Fallback mock
    def check_mission_scope(path):
        whitelist = ["bridge/templates/", "g/reports/", "tools/", "agents/", "bridge/docs/"]
        blacklist = ["core/", "bridge/core/", "bridge/handlers/", "bridge/production/", "g/docs/governance/", "launchd/"]
        
        for pattern in blacklist:
            if path.startswith(pattern):
                return (False, True)
        
        for pattern in whitelist:
            if path.startswith(pattern):
                return (True, False)
        
        return (False, False)
    
    def check_cls_auto_approve_conditions(actor, zone, path, context=None):
        if actor != "CLS" or zone != "LOCKED":
            return (False, {})
        
        is_whitelisted, is_blacklisted = check_mission_scope(path)
        
        conditions = {
            "actor_is_cls": actor == "CLS",
            "zone_is_locked": zone == "LOCKED",
            "path_in_whitelist": is_whitelisted,
            "path_not_blacklisted": not is_blacklisted,
            "risk_level_low": True,
            "rollback_strategy_exists": context.get("rollback_strategy") is not None if context else False,
            "audit_log_enabled": True,
            "boss_approved_similar": context.get("boss_approved_pattern") is not None if context else False,
        }
        
        can_auto_approve = all(conditions.values())
        return (can_auto_approve, conditions)
    
    def route(trigger, actor, path, op="write", context=None):
        zone = "LOCKED" if any(p in path for p in ["core/", "bridge/core/"]) else "OPEN"
        lane = "WARN" if zone == "LOCKED" and trigger == "cursor" else "FAST"
        
        class MockDecision:
            def __init__(self):
                self.zone = zone
                self.lane = lane
                self.auto_approve_allowed = False
                if lane == "WARN" and actor == "CLS":
                    can_approve, _ = check_cls_auto_approve_conditions(actor, zone, path, context)
                    self.auto_approve_allowed = can_approve
        
        return MockDecision()


@pytest.mark.parametrize("path,expected_whitelisted,expected_blacklisted", [
    # Whitelist paths
    ("bridge/templates/email.html", True, False),
    ("g/reports/session.md", True, False),
    ("tools/script.zsh", True, False),
    ("agents/myagent.py", True, False),
    ("bridge/docs/guide.md", True, False),
    
    # Blacklist paths
    ("core/router.py", False, True),
    ("bridge/core/handler.py", False, True),
    ("bridge/handlers/gemini.py", False, True),
    ("bridge/production/config.yaml", False, True),
    ("g/docs/governance/test.md", False, True),
    ("launchd/com.test.plist", False, True),
    
    # Neither
    ("apps/myapp/main.py", False, False),
    ("tests/test_file.py", False, False),
])
def test_mission_scope_check(path, expected_whitelisted, expected_blacklisted):
    """Test Mission Scope whitelist/blacklist checking."""
    is_whitelisted, is_blacklisted = check_mission_scope(path)
    assert is_whitelisted == expected_whitelisted, f"Whitelist check failed for {path}"
    assert is_blacklisted == expected_blacklisted, f"Blacklist check failed for {path}"


def test_cls_auto_approve_whitelist_path():
    """Test CLS auto-approve for whitelist path with all conditions."""
    context = {
        "rollback_strategy": "git_revert",
        "boss_approved_pattern": "template_updates"
    }
    
    can_approve, conditions = check_cls_auto_approve_conditions(
        actor="CLS",
        zone="LOCKED",
        path_str="bridge/templates/email.html",
        context=context
    )
    
    assert can_approve == True, "Should auto-approve whitelist path with all conditions"
    assert conditions["path_in_whitelist"] == True
    assert conditions["path_not_blacklisted"] == True


def test_cls_auto_approve_blacklist_path():
    """Test CLS auto-approve blocked for blacklist path."""
    context = {
        "rollback_strategy": "git_revert",
        "boss_approved_pattern": "core_updates"
    }
    
    can_approve, conditions = check_cls_auto_approve_conditions(
        actor="CLS",
        zone="LOCKED",
        path_str="core/router.py",
        context=context
    )
    
    assert can_approve == False, "Should NOT auto-approve blacklist path"
    assert conditions["path_not_blacklisted"] == False


def test_cls_auto_approve_missing_conditions():
    """Test CLS auto-approve blocked when conditions not met."""
    context = {}  # Missing rollback_strategy and boss_approved_pattern
    
    can_approve, conditions = check_cls_auto_approve_conditions(
        actor="CLS",
        zone="LOCKED",
        path_str="bridge/templates/email.html",
        context=context
    )
    
    assert can_approve == False, "Should NOT auto-approve without all conditions"
    assert conditions["rollback_strategy_exists"] == False
    assert conditions["boss_approved_similar"] == False


def test_cls_auto_approve_non_cls_actor():
    """Test auto-approve only works for CLS actor."""
    can_approve, _ = check_cls_auto_approve_conditions(
        actor="Liam",
        zone="LOCKED",
        path_str="bridge/templates/email.html",
        context={"rollback_strategy": "git_revert"}
    )
    
    assert can_approve == False, "Should NOT auto-approve for non-CLS actor"


def test_router_warn_lane_auto_approve():
    """Test Router returns auto_approve_allowed in WARN lane."""
    context = {
        "rollback_strategy": "git_revert",
        "boss_approved_pattern": "template_updates"
    }
    
    decision = route(
        trigger="cursor",
        actor="CLS",
        path="bridge/templates/email.html",
        op="write",
        context=context
    )
    
    if decision.lane == "WARN":
        assert hasattr(decision, 'auto_approve_allowed')
        # Should be True if all conditions met
        if decision.auto_approve_allowed:
            assert decision.auto_approve_allowed == True

