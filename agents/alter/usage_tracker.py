"""
Dual quota tracker for Alter API usage.

Tracks daily fair-use (200/day) and lifetime usage (40k requests),
persisting aggregated stats and JSONL request logs.
"""

from __future__ import annotations

import datetime as _dt
import json
import os
from pathlib import Path
from typing import Callable, Dict, Optional, Tuple

DEFAULT_DAILY_LIMIT = 200
DEFAULT_LIFETIME_LIMIT = 40000
DAILY_ALERT_RATIO = 0.9  # 90% of daily fair-use limit
LIFETIME_ALERT_RATIO = 0.8  # 80% of lifetime quota


class UsageTracker:
    """Tracks Alter usage against daily and lifetime quotas."""

    def __init__(
        self,
        base_dir: Optional[Path] = None,
        log_path: Optional[Path] = None,
        stats_path: Optional[Path] = None,
        daily_limit: int = DEFAULT_DAILY_LIMIT,
        lifetime_limit: int = DEFAULT_LIFETIME_LIMIT,
        daily_alert_ratio: float = DAILY_ALERT_RATIO,
        lifetime_alert_ratio: float = LIFETIME_ALERT_RATIO,
        now_fn: Optional[Callable[[], _dt.datetime]] = None,
    ):
        if base_dir:
            self.base_dir = Path(base_dir).resolve()
        else:
            base_dir_env = os.getenv("LAC_BASE_DIR")
            self.base_dir = Path(base_dir_env).resolve() if base_dir_env else Path.cwd().resolve()
        self.log_path = Path(log_path) if log_path else self.base_dir / "g" / "data" / "memory" / "alter_usage.jsonl"
        self.stats_path = Path(stats_path) if stats_path else self.base_dir / "g" / "data" / "memory" / "alter_usage_stats.json"
        self.daily_limit = daily_limit
        self.lifetime_limit = lifetime_limit
        self.daily_alert_ratio = daily_alert_ratio
        self.lifetime_alert_ratio = lifetime_alert_ratio
        self._now_fn = now_fn

    def check_quota(self, count: int = 0) -> Dict[str, bool]:
        """
        Return whether the requested count keeps usage within limits.

        Args:
            count: Number of additional requests to evaluate.
        """
        if count < 0:
            raise ValueError("count must be non-negative")
        state = self._load_state()
        daily_ok = state["daily"]["used"] + count <= self.daily_limit
        lifetime_ok = state["lifetime"]["used"] + count <= self.lifetime_limit
        return {"daily": daily_ok, "lifetime": lifetime_ok}

    def record_usage(self, count: int = 1) -> Dict[str, int]:
        """Record usage, update stats, and append a JSONL log entry."""
        if count < 0:
            raise ValueError("count must be non-negative")

        state = self._load_state()
        now = self._now()

        state["daily"]["used"] += count
        state["lifetime"]["used"] += count
        state["updated_at"] = now.isoformat()

        self._persist_state(state)
        self._append_log(count, state, now)

        return {"daily": state["daily"]["used"], "lifetime": state["lifetime"]["used"]}

    def get_remaining(self) -> Dict[str, int]:
        state = self._load_state()
        return {
            "daily": max(self.daily_limit - state["daily"]["used"], 0),
            "lifetime": max(self.lifetime_limit - state["lifetime"]["used"], 0),
        }

    def should_alert(self) -> Dict[str, bool]:
        state = self._load_state()
        daily_ratio = self._ratio(state["daily"]["used"], self.daily_limit)
        lifetime_ratio = self._ratio(state["lifetime"]["used"], self.lifetime_limit)
        return {
            "daily": daily_ratio >= self.daily_alert_ratio,
            "lifetime": lifetime_ratio >= self.lifetime_alert_ratio,
        }

    def get_daily_count(self) -> int:
        state = self._load_state()
        return state["daily"]["used"]

    def get_lifetime_count(self) -> int:
        state = self._load_state()
        return state["lifetime"]["used"]

    def _ratio(self, used: int, limit: int) -> float:
        if limit <= 0:
            return 1.0
        return float(used) / float(limit)

    def _now(self) -> _dt.datetime:
        return self._now_fn() if self._now_fn else _dt.datetime.utcnow()

    def _today_str(self) -> str:
        return self._now().date().isoformat()

    def _default_state(self) -> Dict:
        today = self._today_str()
        return {
            "daily": {"limit": self.daily_limit, "used": 0, "last_reset": today},
            "lifetime": {"limit": self.lifetime_limit, "used": 0},
            "updated_at": self._now().isoformat(),
        }

    def _load_state(self) -> Dict:
        state = self._default_state()
        if self.stats_path.exists():
            try:
                with self.stats_path.open("r", encoding="utf-8") as handle:
                    data = json.load(handle) or {}
                state["daily"]["used"] = self._as_int(data.get("daily", {}).get("used"), 0)
                state["daily"]["last_reset"] = data.get("daily", {}).get("last_reset", state["daily"]["last_reset"])
                state["lifetime"]["used"] = self._as_int(data.get("lifetime", {}).get("used"), 0)
                state["updated_at"] = data.get("updated_at", state["updated_at"])
            except (json.JSONDecodeError, OSError, ValueError):
                state = self._default_state()

        state["daily"]["limit"] = self.daily_limit
        state["lifetime"]["limit"] = self.lifetime_limit
        state, reset = self._maybe_reset_daily(state)

        if reset or not self.stats_path.exists():
            self._persist_state(state)

        return state

    def _persist_state(self, state: Dict) -> None:
        self.stats_path.parent.mkdir(parents=True, exist_ok=True)
        with self.stats_path.open("w", encoding="utf-8") as handle:
            json.dump(state, handle, indent=2)

    def _append_log(self, count: int, state: Dict, now: _dt.datetime) -> None:
        self.log_path.parent.mkdir(parents=True, exist_ok=True)
        entry = {
            "timestamp": now.isoformat(),
            "count": count,
            "daily_used": state["daily"]["used"],
            "lifetime_used": state["lifetime"]["used"],
            "daily_limit": self.daily_limit,
            "lifetime_limit": self.lifetime_limit,
            "within_daily": state["daily"]["used"] <= self.daily_limit,
            "within_lifetime": state["lifetime"]["used"] <= self.lifetime_limit,
        }
        with self.log_path.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(entry) + "\n")

    def _maybe_reset_daily(self, state: Dict) -> Tuple[Dict, bool]:
        today = self._today_str()
        last_reset = state["daily"].get("last_reset")
        if last_reset != today:
            state["daily"]["used"] = 0
            state["daily"]["last_reset"] = today
            return state, True
        return state, False

    def _as_int(self, value, default: int = 0) -> int:
        try:
            return int(value)
        except (TypeError, ValueError):
            return default


__all__ = ["UsageTracker"]
