"""
Paid lane guard and ledger helpers (free-first, emergency-only).
Aligns with lac_contract_v2 + SPEC/PLAN V2.
"""

from __future__ import annotations

import json
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Tuple

try:
    import yaml
except ImportError:  # pragma: no cover
    yaml = None


DEFAULT_CONFIG_PATH = Path("config/paid_lanes.yaml")
LEDGER_PATH_DEFAULT = Path("g/ledger/paid_lane_spend.json")


def _config_path() -> Path:
    override = os.getenv("LAC_PAID_LANES_CONFIG")
    return Path(override) if override else DEFAULT_CONFIG_PATH


def _ledger_path() -> Path:
    override = os.getenv("LAC_PAID_LANES_LEDGER")
    return Path(override) if override else LEDGER_PATH_DEFAULT


def load_paid_config() -> Dict[str, Any]:
    path = _config_path()
    if not path.exists():
        return {
            "paid_lanes": {
                "enabled": False,
                "require_approval": True,
                "emergency_budget_thb": 50,
                "warn_ratio": 0.8,
                "reset_daily": True,
            }
        }
    raw = path.read_text()
    if yaml and path.suffix.lower() in {".yaml", ".yml"}:
        data = yaml.safe_load(raw) or {}
    else:
        data = json.loads(raw)
    return data


def load_paid_ledger() -> Dict[str, Any]:
    path = _ledger_path()
    if not path.exists():
        return {
            "date": _today(),
            "total_spend": 0,
            "model_breakdown": {},
            "last_call_ts": None,
        }
    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError:
        data = {}
    if data.get("date") != _today():
        data = {
            "date": _today(),
            "total_spend": 0,
            "model_breakdown": {},
            "last_call_ts": None,
        }
    return data


def save_paid_ledger(data: Dict[str, Any]) -> None:
    path = _ledger_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2))


def _today() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")


def estimate_cost(call: Dict[str, Any]) -> float:
    return float(call.get("cost_estimate_thb", 0) or 0)


def check_paid_lane_allowed(wo: Dict[str, Any], cost_estimate: float) -> Tuple[bool, str]:
    cfg = load_paid_config().get("paid_lanes", {})
    if not cfg.get("enabled", False):
        return False, "PAID_LANE_DISABLED"

    if cfg.get("require_approval", True) and not wo.get("requires_paid_lane", False):
        return False, "PAID_LANE_NEEDS_APPROVAL"

    ledger = load_paid_ledger()
    budget = cfg.get("emergency_budget_thb", 50)
    projected = ledger.get("total_spend", 0) + cost_estimate
    if projected > budget:
        return False, "PAID_LANE_BUDGET_EXCEEDED"

    return True, "ALLOWED"


def record_paid_lane_usage(model_name: str, cost_spent: float) -> Dict[str, Any]:
    ledger = load_paid_ledger()
    ledger["total_spend"] = ledger.get("total_spend", 0) + cost_spent
    breakdown = ledger.get("model_breakdown", {})
    breakdown[model_name] = breakdown.get(model_name, 0) + cost_spent
    ledger["model_breakdown"] = breakdown
    ledger["last_call_ts"] = datetime.now(timezone.utc).isoformat()
    save_paid_ledger(ledger)
    return ledger


def run_paid_call(wo: Dict[str, Any], model_name: str, call: Any, cost_estimate: float = 0) -> Dict[str, Any]:
    allowed, reason = check_paid_lane_allowed(wo, cost_estimate)
    if not allowed:
        return {"status": "blocked", "reason": reason}

    result = call()
    record_paid_lane_usage(model_name, cost_estimate)
    return {"status": "success", "call_result": result}


__all__ = [
    "check_paid_lane_allowed",
    "record_paid_lane_usage",
    "run_paid_call",
    "estimate_cost",
    "load_paid_config",
    "load_paid_ledger",
    "save_paid_ledger",
]
