from __future__ import annotations

from agents.architect import ArchitectAgent
from agents.dev_common.spec_consumer import summarize_architect_spec, validate_architect_spec


def test_architect_agent_generates_spec():
    agent = ArchitectAgent()
    spec = agent.design({"wo_id": "REQ-20251129-02", "objective": "Create a new API layer", "complexity": "moderate"})

    assert spec["spec_version"] == "1.0"
    assert spec["requirement_id"] == "REQ-20251129-02"
    assert spec["architecture"]["structure"]["modules"]
    assert spec["architecture"]["patterns"]
    assert spec["qa_checklist"]
    assert validate_architect_spec(spec)
    assert summarize_architect_spec(spec)


def test_complex_specs_raise_testing_bar():
    agent = ArchitectAgent()
    spec = agent.design({"wo_id": "REQ-20251129-03", "objective": "Handle complex workflows", "complexity": "complex"})

    testing = spec["architecture"]["standards"]["testing"]
    assert testing["coverage_min"] >= 80
    assert any(check["id"].startswith("test_") for check in spec["qa_checklist"])
