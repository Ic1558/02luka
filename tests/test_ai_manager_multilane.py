from __future__ import annotations

from agents.ai_manager.ai_manager import AIManager


def test_ai_manager_uses_lane_router_hint():
    manager = AIManager()
    wo = {"wo_id": "WO-ROUTE-1", "objective": "Test routing", "complexity": "simple", "source": "cls"}
    task = manager.build_dev_task(wo)
    assert task["routing_hint"] == "dev_codex"


def test_ai_manager_fallbacks_to_default_lane():
    manager = AIManager()
    wo = {"wo_id": "WO-ROUTE-2", "objective": "Test routing default", "complexity": "simple", "source": "unknown"}
    task = manager.build_dev_task(wo)
    assert task["routing_hint"] == "dev_oss"
