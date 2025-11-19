from __future__ import annotations

from datetime import datetime
from typing import Any, Dict


HEAVY_INTENTS = {"bulk_test_generation", "large_refactor", "spec_to_tests"}
LOCKED_IMPACT_ZONES = {
    "locked",
    "governance",
    "bridge_core",
    "/clc",
    "/cls",
}


def _normalize_zones(value: Any) -> list[str]:
    """Return a list of normalized zone strings for comparison."""
    if isinstance(value, str):
        return [value]
    if isinstance(value, (list, tuple, set)):
        return [str(zone) for zone in value if zone]
    return []


def _is_locked_zone(payload: Dict[str, Any]) -> bool:
    """Detect whether a payload targets a locked/governance zone."""
    if payload.get("locked_zone"):
        return True

    for zone in _normalize_zones(payload.get("impact_zone")):
        if zone.lower() in LOCKED_IMPACT_ZONES:
            return True

    return False


def route_engine(intent: str, payload: Dict[str, Any]) -> str:
    """Return the execution engine for a given Kim intent and payload."""

    if _is_locked_zone(payload):
        return "CLC"

    if not intent or not isinstance(intent, str):
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
