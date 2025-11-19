#!/usr/bin/env python3
"""
Multi-engine quota tracker for dashboard metrics.

Tracks token usage per agent, persists history, and exposes helpers for the dashboard API.
"""

from __future__ import annotations

import argparse
import datetime
import importlib
import importlib.util
import json
import os
from pathlib import Path
from typing import Dict, List, Optional, Union

ROOT = Path(__file__).resolve().parents[2]
CONFIG_CANDIDATES = [
    ROOT / "config" / "quota_limits.yaml",
    ROOT / "g" / "config" / "quota_config.yaml",
]
HISTORY_PATH = ROOT / "g" / "reports" / "quota" / "quota_history.jsonl"
RAW_USAGE_PATH = ROOT / "g" / "apps" / "dashboard" / "data" / "quota_usage_raw.json"
METRICS_PATH = RAW_USAGE_PATH.parent / "quota_metrics.json"

DAILY_TTL = 60 * 60 * 24
MONTHLY_TTL = 60 * 60 * 24 * 35
MAX_HISTORY_READ = 2000


def _load_yaml_module():
    spec = importlib.util.find_spec("yaml")
    if spec is None:
        return None
    return importlib.import_module("yaml")


def _ensure_dir(path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)


def _iso_now():
    return datetime.datetime.now(datetime.timezone.utc)


def _parse_iso(value: Optional[str]) -> Optional[datetime.datetime]:
    if not value:
        return None
    try:
        if value.endswith("Z"):
            value = value[:-1] + "+00:00"
        return datetime.datetime.fromisoformat(value)
    except ValueError:
        try:
            return datetime.datetime.strptime(value, "%Y-%m-%dT%H:%M:%S.%f")
        except ValueError:
            return None


class QuotaTracker:
    """Records quota consumption and builds normalized metrics."""

    def __init__(
        self,
        redis_client=None,
        config_path: Optional[Path] = None,
        history_path: Optional[Path] = None,
    ):
        self._config_path = config_path or self._find_config()
        self._config = self._load_config()
        self._history_path = history_path or HISTORY_PATH
        self.redis_client = redis_client if redis_client is not None else self._build_redis_client()

    def _find_config(self) -> Path:
        for candidate in CONFIG_CANDIDATES:
            if candidate.exists():
                return candidate
        raise FileNotFoundError(f"quota config not found (checked: {CONFIG_CANDIDATES})")

    def _load_config(self) -> Dict:
        yaml = _load_yaml_module()
        if yaml is None:
            raise SystemExit("[quota_tracker] PyYAML not installed; cannot parse config")
        with self._config_path.open("r", encoding="utf-8") as handle:
            data = yaml.safe_load(handle) or {}
        agents = data.get("agents", {})
        for agent_cfg in agents.values():
            agent_cfg.setdefault("warn_ratio", 0.8)
            agent_cfg.setdefault("critical_ratio", agent_cfg.get("stop_ratio", 0.95))
        return {"agents": agents}

    def _build_redis_client(self):
        try:
            import redis
        except ImportError:
            return None

        redis_url = os.getenv("REDIS_URL")
        redis_host = os.getenv("REDIS_HOST", "127.0.0.1")
        redis_port = int(os.getenv("REDIS_PORT", "6379"))
        redis_pass = os.getenv("REDIS_PASSWORD")
        try:
            if redis_url:
                client = redis.Redis.from_url(redis_url, decode_responses=True)
            else:
                client = redis.Redis(
                    host=redis_host,
                    port=redis_port,
                    password=redis_pass if redis_pass else None,
                    decode_responses=True,
                )
            client.ping()
            return client
        except Exception:
            return None

    @staticmethod
    def _to_float(value: Union[float, str, None]) -> float:
        if value is None:
            return 0.0
        try:
            return float(value)
        except (TypeError, ValueError):
            return 0.0

    def _history_records(self, limit: int = MAX_HISTORY_READ) -> List[Dict]:
        if not self._history_path.exists():
            return []
        records: List[Dict] = []
        with self._history_path.open("r", encoding="utf-8") as handle:
            for line in handle:
                line = line.strip()
                if not line:
                    continue
                try:
                    records.append(json.loads(line))
                except json.JSONDecodeError:
                    continue
        return records[-limit:]

    def _append_history(self, entry: Dict):
        _ensure_dir(self._history_path)
        with self._history_path.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(entry, ensure_ascii=False) + "\n")

    def _write_raw_usage(self, agent: str, tokens: float) -> float:
        data = {}
        if RAW_USAGE_PATH.exists():
            try:
                with RAW_USAGE_PATH.open("r", encoding="utf-8") as handle:
                    data = json.load(handle)
            except json.JSONDecodeError:
                data = {}
        data.setdefault(agent, {})
        existing = self._to_float(data[agent].get("used"))
        data[agent]["used"] = existing + tokens
        _ensure_dir(RAW_USAGE_PATH)
        with RAW_USAGE_PATH.open("w", encoding="utf-8") as handle:
            json.dump(data, handle, ensure_ascii=False, indent=2)
        return data[agent]["used"]

    def record(
        self,
        agent: str,
        tokens_used: float,
        request_id: Optional[str] = None,
        cost_usd: Optional[float] = None,
        timestamp: Optional[datetime.datetime] = None,
    ) -> Dict:
        if not agent or tokens_used is None or tokens_used < 0:
            raise ValueError("agent and positive tokens_used are required")

        now = timestamp or _iso_now()
        day_key = now.strftime("%Y-%m-%d")
        month_key = now.strftime("%Y-%m")
        totals = {"daily": tokens_used, "monthly": tokens_used}

        if self.redis_client:
            totals = self._record_with_redis(agent, tokens_used, day_key, month_key)
        else:
            fallback_monthly = self._write_raw_usage(agent, tokens_used)
            totals = {"daily": tokens_used, "monthly": fallback_monthly}

        entry = {
            "agent": agent,
            "timestamp": now.isoformat(),
            "tokens_used": tokens_used,
            "request_id": request_id,
            "cost_usd": cost_usd,
            "daily_total": totals["daily"],
            "monthly_total": totals["monthly"],
        }
        self._append_history(entry)
        try:
            self.sync_metrics()
        except Exception:
            pass
        return entry

    def _record_with_redis(self, agent: str, tokens_used: float, day_key: str, month_key: str):
        pipeline = self.redis_client.pipeline()
        pipeline.incrbyfloat(f"quota:{agent}:daily:{day_key}", tokens_used)
        pipeline.incrbyfloat(f"quota:{agent}:monthly:{month_key}", tokens_used)
        pipeline.expire(f"quota:{agent}:daily:{day_key}", DAILY_TTL)
        pipeline.expire(f"quota:{agent}:monthly:{month_key}", MONTHLY_TTL)
        pipeline.get(f"quota:{agent}:daily:{day_key}")
        pipeline.get(f"quota:{agent}:monthly:{month_key}")
        results = pipeline.execute()
        day_total = self._to_float(results[-2])
        month_total = self._to_float(results[-1])
        return {"daily": day_total, "monthly": month_total}

    def _sum_history(self, agent: str, since: datetime.datetime) -> float:
        records = self._history_records()
        total = 0.0
        for record in records:
            if record.get("agent") != agent:
                continue
            ts = _parse_iso(record.get("timestamp"))
            if not ts or ts < since:
                continue
            total += self._to_float(record.get("tokens_used"))
        return total

    def _sum_history_cost(self, agent: str, since: datetime.datetime) -> float:
        records = self._history_records()
        total = 0.0
        for record in records:
            if record.get("agent") != agent:
                continue
            ts = _parse_iso(record.get("timestamp"))
            if not ts or ts < since:
                continue
            total += self._to_float(record.get("cost_usd"))
        return total

    def _get_total(self, agent: str, scope: str, since: datetime.datetime) -> float:
        if self.redis_client:
            key = f"quota:{agent}:{scope}:{since.strftime('%Y-%m-%d' if scope == 'daily' else '%Y-%m')}"
            try:
                return self._to_float(self.redis_client.get(key))
            except Exception:
                return 0.0
        if scope == "daily":
            return self._sum_history(agent, since)
        return self._sum_history(agent, since)

    def get_status(self) -> Dict:
        now = _iso_now()
        start_of_day = now.replace(hour=0, minute=0, second=0, microsecond=0)
        month_str = now.strftime("%Y-%m")
        start_of_month = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        agents_status = {}
        for name, cfg in self._config.get("agents", {}).items():
            daily_total = self._get_total(name, "daily", start_of_day)
            monthly_total = self._get_total(name, "monthly", start_of_month)
            limits = {
                "daily_limit": self._to_float(cfg.get("daily_limit")),
                "monthly_limit": self._to_float(cfg.get("monthly_limit")),
            }
            warn = self._to_float(cfg.get("warn_ratio", 0.8))
            critical = self._to_float(cfg.get("critical_ratio", 0.95))
            ratio = monthly_total / limits["monthly_limit"] if limits["monthly_limit"] > 0 else 0.0
            if limits["monthly_limit"] <= 0:
                status = "unknown"
            elif ratio >= critical:
                status = "critical"
            elif ratio >= warn:
                status = "warning"
            else:
                status = "healthy"

            daily_pct = (daily_total / limits["daily_limit"] * 100) if limits["daily_limit"] > 0 else 0
            monthly_pct = min(int(ratio * 100), 100) if limits["monthly_limit"] > 0 else 0

            agents_status[name] = {
                "label": cfg.get("label", name),
                "daily_total": daily_total,
                "monthly_total": monthly_total,
                "daily_limit": limits["daily_limit"],
                "monthly_limit": limits["monthly_limit"],
                "status": status,
                "daily_pct": round(daily_pct),
                "monthly_pct": monthly_pct,
                "remaining_monthly": max(0.0, limits["monthly_limit"] - monthly_total) if limits["monthly_limit"] > 0 else None,
                "cost_today_usd": self._sum_history_cost(name, start_of_day),
            }
        return {
            "updated_at": now.isoformat(),
            "month": month_str,
            "agents": agents_status,
        }

    def get_limits(self) -> Dict:
        return self._config.get("agents", {})

    def get_history(self, agent: Optional[str] = None, days: int = 7, limit: int = 500) -> List[Dict]:
        if days <= 0:
            days = 7
        since = _iso_now() - datetime.timedelta(days=days)
        records = []
        for entry in self._history_records(limit * 3):
            if agent and entry.get("agent") != agent:
                continue
            ts = _parse_iso(entry.get("timestamp"))
            if not ts or ts < since:
                continue
            records.append(entry)
        return records[-limit:]

    def sync_metrics(self) -> None:
        metrics = self.get_status()
        _ensure_dir(METRICS_PATH)
        with METRICS_PATH.open("w", encoding="utf-8") as handle:
            json.dump(metrics, handle, ensure_ascii=False, indent=2)


def _build_parser():
    parser = argparse.ArgumentParser(description="Quota tracker helper")
    subparsers = parser.add_subparsers(dest="command")

    status = subparsers.add_parser("status", help="Show current quota status")
    status.set_defaults(func=lambda tracker, args: print(json.dumps(tracker.get_status(), indent=2)))

    limits = subparsers.add_parser("limits", help="Dump configured limits")
    limits.set_defaults(func=lambda tracker, args: print(json.dumps(tracker.get_limits(), indent=2)))

    history = subparsers.add_parser("history", help="Show recent history records")
    history.add_argument("--agent", help="Filter by agent name")
    history.add_argument("--days", type=int, default=7, help="History window in days")
    history.set_defaults(func=lambda tracker, args: print(json.dumps(tracker.get_history(args.agent, args.days), indent=2)))

    record = subparsers.add_parser("record", help="Record a quota usage event")
    record.add_argument("--agent", required=True)
    record.add_argument("--tokens", type=float, required=True)
    record.add_argument("--cost", type=float, default=None)
    record.add_argument("--request-id", help="Optional request identifier")
    record.set_defaults(func=lambda tracker, args: print(json.dumps(
        tracker.record(
            args.agent,
            args.tokens,
            request_id=args.request_id,
            cost_usd=args.cost,
        ),
        indent=2,
    )))

    return parser


def main():
    parser = _build_parser()
    args = parser.parse_args()
    tracker = QuotaTracker()

    if not args.command:
        parser.print_help()
        return

    tracker.sync_metrics()
    args.func(tracker, args)


if __name__ == "__main__":
    main()
