import pytest

from agents.ai_manager.ai_manager import AIManager


def test_ai_manager_policy_deny_locked_zone():
    manager = AIManager()
    wo = {
        "wo_id": "TEST-001",
        "objective": "Hack the core",
        "files": ["CLC/core.py"],
        "source": "Liam",
        "routing_hint": "dev_oss",
        "complexity": "simple",
    }

    task = manager.build_dev_task(wo)
    routing = wo.get("routing", {})
    assert routing.get("approved") is False
    assert "GOVERNANCE_DENY" in routing.get("reason", "")
    assert task["routing_hint"] == routing.get("lane")


def test_ai_manager_policy_allow_open_zone():
    manager = AIManager()
    wo = {
        "wo_id": "TEST-002",
        "objective": "Fix a bug",
        "files": ["agents/liam/core.py"],
        "source": "Liam",
        "routing_hint": "dev_oss",
        "complexity": "simple",
    }

    task = manager.build_dev_task(wo)
    routing = wo.get("routing", {})
    assert routing.get("approved") is True
    assert routing.get("lane") == "dev_oss"
    assert task["routing_hint"] == "dev_oss"


def test_ai_manager_policy_deny_unknown_default():
    manager = AIManager()
    # No source/writer provided
    wo = {
        "wo_id": "TEST-003",
        "objective": "Anonymous hack",
        "files": ["agents/liam/core.py"], # Open zone
        "routing_hint": "dev_oss",
        "complexity": "simple",
    }

    task = manager.build_dev_task(wo)
    routing = wo.get("routing", {})
    
    # Should be denied because writer defaults to UNKNOWN, which is not in allowed_writers
    assert routing.get("approved") is False
    assert "GOVERNANCE_DENY" in routing.get("reason", "")
    assert wo.get("writer") == "UNKNOWN"

