#!/usr/bin/env python3
"""
Battle-Test Suite: Matrix 1 — World × Zone × Lane Coverage
Tests the complete routing matrix for Governance v5

Run: python3 -m pytest tests/v5_battle/test_matrix1_routing.py -v
"""

import pytest
import sys
from pathlib import Path

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from bridge.core.router_v5 import (
    route, resolve_world, resolve_zone, resolve_lane,
    determine_primary_writer, check_cls_auto_approve_conditions
)


class TestMatrix1WorldZoneLane:
    """Matrix 1: World × Zone × Lane Coverage (M1-01 to M1-10)"""
    
    # =========================================================================
    # M1-01 to M1-06: CLI World Tests
    # =========================================================================
    
    def test_M1_01_cli_open_fast_cls(self):
        """M1-01: CLI + OPEN + FAST + CLS → Direct write"""
        decision = route(
            trigger="cursor",
            actor="CLS",
            path="g/reports/test.md",
            op="write"
        )
        assert decision.zone == "OPEN"
        assert decision.lane == "FAST"
        assert decision.primary_writer == "CLS"
        assert "Direct" in decision.reason or "OPEN" in decision.reason
    
    def test_M1_02_cli_open_fast_liam(self):
        """M1-02: CLI + OPEN + FAST + Liam → Direct write (multi-actor)"""
        decision = route(
            trigger="terminal",
            actor="Liam",
            path="tools/test.zsh",
            op="write"
        )
        assert decision.zone == "OPEN"
        assert decision.lane == "FAST"
        assert decision.primary_writer == "Liam"
    
    def test_M1_03_cli_locked_warn_cls_auto_approve(self):
        """M1-03: CLI + LOCKED + WARN + CLS → Ask or Auto-approve"""
        decision = route(
            trigger="antigravity",
            actor="CLS",
            path="bridge/core/test_config.yaml",  # LOCKED zone
            op="write",
            context={
                "rollback_strategy": "git_revert",
                "boss_approved_pattern": True
            }
        )
        assert decision.zone == "LOCKED"
        assert decision.lane == "WARN"
        # CLS can AUTO-approve if conditions met
        if decision.auto_approve_allowed:
            assert decision.auto_approve_conditions is not None
    
    def test_M1_04_cli_locked_warn_gmx_no_auto(self):
        """M1-04: CLI + LOCKED + WARN + GMX → No auto-approve"""
        decision = route(
            trigger="gmx",
            actor="GMX",
            path="core/config.py",
            op="write"
        )
        assert decision.zone == "LOCKED"
        assert decision.lane == "WARN"
        assert decision.auto_approve_allowed == False  # GMX cannot auto-approve
    
    def test_M1_05_cli_danger_blocked_cls(self):
        """M1-05: CLI + DANGER + BLOCKED + CLS → Blocked"""
        decision = route(
            trigger="cursor",
            actor="CLS",
            path="/System/Library/test",
            op="write"
        )
        assert decision.zone == "DANGER"
        assert decision.lane == "BLOCKED"
        assert decision.primary_writer is None
    
    def test_M1_06_cli_danger_blocked_boss(self):
        """M1-06: CLI + DANGER + BLOCKED + Boss → Still blocked (needs confirm)"""
        decision = route(
            trigger="human",
            actor="Boss",
            path="/etc/hosts",
            op="write"
        )
        assert decision.zone == "DANGER"
        assert decision.lane == "BLOCKED"
        # Boss can override but only with explicit confirmation (not in route)
    
    # =========================================================================
    # M1-07 to M1-10: Background World Tests
    # =========================================================================
    
    def test_M1_07_bg_open_strict_clc(self):
        """M1-07: BACKGROUND + OPEN + STRICT + CLC → WO + SIP"""
        decision = route(
            trigger="launchd",
            actor="CLC",
            path="g/reports/auto_report.md",
            op="write",
            context={"wo_id": "WO-TEST-001"}
        )
        assert decision.lane == "STRICT"
        assert decision.primary_writer == "CLC"
    
    def test_M1_08_bg_locked_strict_clc(self):
        """M1-08: BACKGROUND + LOCKED + STRICT + CLC → WO + SIP (LOCKED)"""
        decision = route(
            trigger="cron",
            actor="CLC",
            path="bridge/core/auto_config.py",
            op="write",
            context={"wo_id": "WO-TEST-002"}
        )
        assert decision.zone == "LOCKED"
        assert decision.lane == "STRICT"
        assert decision.primary_writer == "CLC"
    
    def test_M1_09_bg_danger_blocked_clc(self):
        """M1-09: BACKGROUND + DANGER + BLOCKED + CLC → Blocked (BG can't override)"""
        decision = route(
            trigger="daemon",
            actor="CLC",
            path="/usr/local/bin/test",
            op="write",
            context={"wo_id": "WO-TEST-003"}
        )
        assert decision.zone == "DANGER"
        assert decision.lane == "BLOCKED"
        assert decision.primary_writer is None
    
    def test_M1_10_bg_open_strict_lpe(self):
        """M1-10: BACKGROUND + OPEN + STRICT + LPE → Emergency fallback"""
        # Note: LPE is emergency backup for CLC
        decision = route(
            trigger="watchdog",
            actor="LPE",
            path="g/logs/emergency.log",
            op="write",
            context={"wo_id": "WO-EMERGENCY-001"}
        )
        assert decision.lane == "STRICT"
        # LPE is background actor, should route through CLC path


class TestMatrix1EdgeCases:
    """Edge cases and boundary conditions"""
    
    def test_unknown_trigger_defaults_cli(self):
        """Unknown trigger should raise ValueError (strict validation)"""
        import pytest
        with pytest.raises(ValueError):
            resolve_world("unknown_source")
    
    def test_wo_context_forces_background(self):
        """WO ID in context should force BACKGROUND world"""
        world = resolve_world("unknown", context={"wo_id": "WO-123"})
        assert world == "BACKGROUND"
    
    def test_planner_cannot_write(self):
        """Planners (GG, GM) cannot be primary writer"""
        decision = route(
            trigger="cursor",
            actor="GG",
            path="g/reports/plan.md",
            op="write"
        )
        assert decision.primary_writer is None
    
    def test_router_cannot_write(self):
        """Router (Mary) cannot be primary writer"""
        decision = route(
            trigger="cursor",
            actor="Mary",
            path="g/logs/route.log",
            op="write"
        )
        assert decision.primary_writer is None


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
