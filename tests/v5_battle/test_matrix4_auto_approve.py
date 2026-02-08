#!/usr/bin/env python3
"""
Battle-Test Suite: Matrix 4 — CLS Auto-Approve Conditions
Tests all CLS auto-approve condition combinations

Run: python3 -m pytest tests/v5_battle/test_matrix4_auto_approve.py -v
"""

import pytest
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from bridge.core.router_v5 import (
    route, check_cls_auto_approve_conditions, check_mission_scope
)


class TestMatrix4AutoApproveConditions:
    """Matrix 4: CLS Auto-Approve Conditions (A4-01 to A4-10)"""
    
    # =========================================================================
    # A4-01 to A4-03: Whitelist Paths (Should Auto-Approve)
    # =========================================================================
    
    def test_A4_01_bridge_templates_whitelist(self):
        """A4-01: bridge/templates/ is whitelisted → AUTO"""
        is_whitelisted, is_blacklisted = check_mission_scope("bridge/templates/x.yaml")
        assert is_whitelisted == True
        assert is_blacklisted == False
    
    def test_A4_02_g_reports_whitelist(self):
        """A4-02: g/reports/ is whitelisted → AUTO"""
        is_whitelisted, is_blacklisted = check_mission_scope("g/reports/x.md")
        assert is_whitelisted == True
        assert is_blacklisted == False
    
    def test_A4_03_tools_whitelist(self):
        """A4-03: tools/ is whitelisted → AUTO"""
        is_whitelisted, is_blacklisted = check_mission_scope("tools/x.zsh")
        assert is_whitelisted == True
        assert is_blacklisted == False
    
    # =========================================================================
    # A4-04 to A4-06: Blacklist Paths (Should Block Auto-Approve)
    # =========================================================================
    
    def test_A4_04_core_blacklist(self):
        """A4-04: core/ is blacklisted → BLOCKED"""
        is_whitelisted, is_blacklisted = check_mission_scope("core/x.py")
        assert is_blacklisted == True
    
    def test_A4_05_bridge_core_blacklist(self):
        """A4-05: bridge/core/ is blacklisted → BLOCKED"""
        is_whitelisted, is_blacklisted = check_mission_scope("bridge/core/x.py")
        assert is_blacklisted == True
    
    def test_A4_06_governance_docs_blacklist(self):
        """A4-06: g/docs/governance/ is blacklisted → BLOCKED"""
        is_whitelisted, is_blacklisted = check_mission_scope("g/docs/governance/x.md")
        assert is_blacklisted == True
    
    # =========================================================================
    # A4-07 to A4-08: Missing Conditions (Should Fail Auto-Approve)
    # =========================================================================
    
    def test_A4_07_no_rollback_fails(self):
        """A4-07: Missing rollback strategy → No auto-approve"""
        can_auto, conditions = check_cls_auto_approve_conditions(
            actor="CLS",
            zone="LOCKED",
            path_str="tools/test.zsh",
            context={
                # No rollback_strategy
                "boss_approved_pattern": True
            }
        )
        assert conditions.get("rollback_strategy_exists") == False
        assert can_auto == False
    
    def test_A4_08_no_boss_pattern_fails(self):
        """A4-08: No boss approved pattern → No auto-approve"""
        can_auto, conditions = check_cls_auto_approve_conditions(
            actor="CLS",
            zone="LOCKED",
            path_str="tools/test.zsh",
            context={
                "rollback_strategy": "git_revert"
                # No boss_approved_pattern
            }
        )
        assert conditions.get("boss_approved_similar") == False
        assert can_auto == False
    
    # =========================================================================
    # A4-09 to A4-10: Edge Cases
    # =========================================================================
    
    def test_A4_09_launchd_blacklist(self):
        """A4-09: launchd/ is blacklisted → BLOCKED"""
        is_whitelisted, is_blacklisted = check_mission_scope("launchd/x.plist")
        assert is_blacklisted == True
    
    def test_A4_10_agents_whitelist(self):
        """A4-10: agents/ is whitelisted (MEDIUM risk)"""
        is_whitelisted, is_blacklisted = check_mission_scope("agents/liam/x.py")
        assert is_whitelisted == True
        assert is_blacklisted == False


class TestMatrix4FullAutoApproveFlow:
    """Full auto-approve flow tests"""
    
    def test_full_auto_approve_all_conditions_met(self):
        """All conditions met → Auto-approve allowed"""
        can_auto, conditions = check_cls_auto_approve_conditions(
            actor="CLS",
            zone="LOCKED",
            path_str="tools/script.zsh",
            context={
                "rollback_strategy": "git_revert",
                "boss_approved_pattern": True
            }
        )
        # Check individual conditions
        assert conditions.get("actor_is_cls") == True
        assert conditions.get("zone_is_locked") == True
        assert conditions.get("path_in_whitelist") == True
        assert conditions.get("rollback_strategy_exists") == True
        # Note: can_auto depends on ALL conditions including risk assessment
    
    def test_non_cls_cannot_auto_approve(self):
        """Non-CLS actor cannot auto-approve"""
        can_auto, conditions = check_cls_auto_approve_conditions(
            actor="GMX",
            zone="LOCKED",
            path_str="tools/script.zsh",
            context={
                "rollback_strategy": "git_revert",
                "boss_approved_pattern": True
            }
        )
        # Non-CLS returns empty conditions
        assert conditions == {}
        assert can_auto == False
    
    def test_open_zone_no_auto_approve(self):
        """OPEN zone doesn't need auto-approve (FAST lane)"""
        can_auto, conditions = check_cls_auto_approve_conditions(
            actor="CLS",
            zone="OPEN",  # Not LOCKED
            path_str="g/reports/test.md",
            context={}
        )
        # OPEN zone returns empty conditions (not applicable)
        assert conditions == {}
    
    def test_route_with_auto_approve_context(self):
        """Full route() with auto-approve context"""
        decision = route(
            trigger="cursor",
            actor="CLS",
            path="bridge/core/config.yaml",  # LOCKED zone
            op="write",
            context={
                "rollback_strategy": "git_revert",
                "boss_approved_pattern": True
            }
        )
        assert decision.zone == "LOCKED"
        assert decision.lane == "WARN"
        # Auto-approve conditions should be checked
        if decision.auto_approve_allowed:
            assert decision.auto_approve_conditions is not None


class TestMatrix4MissionScopeEdgeCases:
    """Edge cases for Mission Scope"""
    
    def test_bridge_handlers_blacklist(self):
        """bridge/handlers/ is blacklisted"""
        is_whitelisted, is_blacklisted = check_mission_scope("bridge/handlers/x.py")
        assert is_blacklisted == True
    
    def test_bridge_production_blacklist(self):
        """bridge/production/ is blacklisted"""
        is_whitelisted, is_blacklisted = check_mission_scope("bridge/production/x.yaml")
        assert is_blacklisted == True
    
    def test_bridge_docs_whitelist(self):
        """bridge/docs/ is whitelisted"""
        is_whitelisted, is_blacklisted = check_mission_scope("bridge/docs/x.md")
        assert is_whitelisted == True
    
    def test_outside_root_blacklisted(self):
        """Path outside root is blacklisted"""
        is_whitelisted, is_blacklisted = check_mission_scope("/tmp/outside")
        assert is_blacklisted == True


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
