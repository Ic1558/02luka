from __future__ import annotations

from agents.ai_manager.ai_manager import AIManager


def test_build_work_order_from_requirement(tmp_path):
    requirement = tmp_path / "Requirement.md"
    requirement.write_text(
        """
# Requirement: Sample Feature
**ID:** REQ-20251129-01
**Priority:** P1
**Complexity:** Simple

## Objective
Build routing integration for AI Manager.
""",
        encoding="utf-8",
    )

    manager = AIManager()
    result = manager.build_work_order_from_requirement(str(requirement), file_count=2)

    assert result["status"] == "ready"
    wo = result["work_order"]
    assert wo["wo_id"] == "REQ-20251129-01"
    assert wo["routing"]["lane"] == "dev_oss"
    assert wo["routing_reason"]


def test_build_work_order_validation_errors(tmp_path):
    requirement = tmp_path / "Requirement.md"
    requirement.write_text(
        """
# Requirement: Invalid Feature
**ID:** 
**Priority:** P2
**Complexity:** Moderate

## Objective
""",
        encoding="utf-8",
    )
    manager = AIManager()

    result = manager.build_work_order_from_requirement(str(requirement))
    assert result["status"] == "invalid"
    assert "INVALID_WO_ID" in result["errors"]
    assert "MISSING_OBJECTIVE" in result["errors"]


def test_docs_done_applies_routing_and_respects_file_count():
    manager = AIManager()
    wo = {"wo_id": "WO-ROUTE-1", "self_apply": True, "complexity": "simple", "file_count": 5}

    state = manager.transition(wo, "DOCS_DONE", None)
    assert state == "ROUTE_TO_CLC"
    assert wo["routing"]["lane"] == "dev_gmxcli"
    assert wo["routing_reason"]


def test_paid_hint_tracks_approval_state():
    manager = AIManager()
    wo = {"wo_id": "WO-PAID-1", "self_apply": False, "complexity": "complex", "routing_hint": "dev_paid"}

    state = manager.transition(wo, "DOCS_DONE", None)
    assert state == "ROUTE_TO_CLC"
    assert wo["routing"]["lane"] in {"dev_paid", "dev_gmxcli"}
    assert wo["routing"].get("approved") is False
    assert wo["routing_reason"] == "paid_disabled_fallback_gmx"
