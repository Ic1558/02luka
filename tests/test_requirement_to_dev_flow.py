from __future__ import annotations

from agents.ai_manager.ai_manager import AIManager
from agents.dev_oss.dev_worker import DevOSSWorker


def test_requirement_to_architect_spec_and_dev_prompt(tmp_path):
    req = tmp_path / "Requirement.md"
    req.write_text(
        """
# Requirement: Sample Feature
**ID:** REQ-20251129-10
**Priority:** P1
**Complexity:** Moderate

## Objective
Create end-to-end flow from requirement to architect spec to dev prompt.
""",
        encoding="utf-8",
    )

    manager = AIManager()
    result = manager.build_work_order_from_requirement(str(req), file_count=2)

    assert result["status"] == "ready"
    wo = result["work_order"]
    spec = wo.get("architect_spec")
    assert spec
    assert spec["architecture"]["structure"]["modules"]
    assert spec["qa_checklist"]

    worker = DevOSSWorker(backend=None)
    prompt = worker._build_prompt(
        {
            "wo_id": wo["wo_id"],
            "objective": wo["objective"],
            "routing_hint": wo.get("routing_hint"),
            "priority": wo.get("priority"),
            "architect_spec": spec,
        }
    )

    assert "ArchitectSpec:" in prompt
    first_module = spec["architecture"]["structure"]["modules"][0]["name"]
    assert first_module in prompt
