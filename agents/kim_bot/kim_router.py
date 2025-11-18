from __future__ import annotations

from datetime import datetime
from typing import Any, Dict


HEAVY_INTENTS = {"bulk_test_generation", "large_refactor", "spec_to_tests"}


def route_engine(intent: str, payload: Dict[str, Any]) -> str:
    """Return the execution engine for a given Kim intent and payload."""

    if payload.get("locked_zone"):
        return "CLC"

    if intent in HEAVY_INTENTS:
        return "GEMINI"

    return "CLC"


def build_work_order(intent: str, payload: Dict[str, Any]) -> Dict[str, Any]:
    """Construct a work order dictionary consumable by the dispatcher."""

    engine = route_engine(intent, payload)
    wo_id = payload.get("wo_id") or f"{engine}_{datetime.utcnow():%Y%m%d_%H%M%S}"

    wo: Dict[str, Any] = {
        "wo_id": wo_id,
        "engine": engine,
        "task_type": intent,
        "priority": payload.get("priority", "normal"),
        "input": {
            "instructions": payload.get("instructions", ""),
            "target_files": payload.get("target_files", []),
            "context": payload.get("context", {}),
            "impact_zone": payload.get("impact_zone", "apps"),
            "locked_zone": bool(payload.get("locked_zone", False)),
        },
        "meta": payload.get("meta", {}),
    }

    return wo
