#!/usr/bin/env python3
"""Read-only LAC state access."""

from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Dict, Optional


STATE_PATH = Path(__file__).resolve().parent / "lac_state.yaml"
RECENT_WINDOW = timedelta(minutes=60)


def _parse_scalar(value: str) -> Any:
    if value in ("null", "~"):
        return None
    if value.startswith('"') and value.endswith('"'):
        try:
            return json.loads(value)
        except json.JSONDecodeError:
            return value.strip('"')
    if value.startswith("'") and value.endswith("'"):
        return value.strip("'")
    return value


def _parse_state(text: str) -> Dict[str, Any]:
    stripped = text.lstrip()
    if stripped.startswith("{"):
        try:
            return json.loads(text)
        except json.JSONDecodeError:
            return {}

    data: Dict[str, Any] = {"version": None, "updated_at": None, "lanes": {}}
    in_lanes = False
    current_lane: Optional[str] = None
    for raw in text.splitlines():
        line = raw.split("#", 1)[0].rstrip()
        if not line.strip():
            continue
        if line.startswith("version:"):
            data["version"] = _parse_scalar(line.split(":", 1)[1].strip())
            continue
        if line.startswith("updated_at:"):
            data["updated_at"] = _parse_scalar(line.split(":", 1)[1].strip())
            continue
        if line.startswith("lanes:"):
            in_lanes = True
            tail = line.split(":", 1)[1].strip()
            if tail == "{}":
                data["lanes"] = {}
                in_lanes = False
            continue
        if in_lanes and line.startswith("  ") and not line.startswith("    "):
            lane = line.strip()
            if lane.endswith(":"):
                lane = lane[:-1].strip()
            current_lane = lane or None
            if current_lane:
                data["lanes"].setdefault(current_lane, {})
            continue
        if in_lanes and line.startswith("    ") and current_lane:
            key, _, raw_value = line.strip().partition(":")
            data["lanes"][current_lane][key.strip()] = _parse_scalar(raw_value.strip())
    return data


def _load_state(path: Path) -> Dict[str, Any]:
    if not path.exists():
        return {}
    try:
        return _parse_state(path.read_text(encoding="utf-8"))
    except Exception:
        return {}


def _parse_ts(value: Optional[str]) -> Optional[datetime]:
    if not value:
        return None
    try:
        text = value.replace("Z", "+00:00")
        parsed = datetime.fromisoformat(text)
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=datetime.now().astimezone().tzinfo)
    return parsed.astimezone(timezone.utc)


def check_lac_before_work(my_lane: str) -> Dict[str, Any]:
    """
    Return the caller lane state, recent work within 60 minutes, and busy signal.
    Never raises on error.
    """
    try:
        state = _load_state(STATE_PATH)
        lanes = state.get("lanes") if isinstance(state, dict) else None
        lanes = lanes if isinstance(lanes, dict) else {}

        my_lane_state = lanes.get(my_lane)
        recent_work: Dict[str, Any] = {}

        now = datetime.now(timezone.utc)
        for lane, info in lanes.items():
            if not isinstance(info, dict):
                continue
            last_ts = _parse_ts(info.get("last_ts"))
            if last_ts and now - last_ts <= RECENT_WINDOW:
                recent_work[lane] = info

        is_busy = any(
            info.get("status") == "running" for info in recent_work.values() if isinstance(info, dict)
        )

        return {
            "my_lane": my_lane_state if isinstance(my_lane_state, dict) else None,
            "recent_work": recent_work,
            "is_busy": is_busy,
        }
    except Exception:
        return {"my_lane": None, "recent_work": {}, "is_busy": False}


__all__ = ["check_lac_before_work"]
