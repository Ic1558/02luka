#!/usr/bin/env python3
"""
Generate Alter AI usage report (daily + lifetime).
"""

from __future__ import annotations

import argparse
import datetime as _dt
import json
from pathlib import Path
from typing import Dict, List

from agents.alter.usage_tracker import UsageTracker


def _percent(used: int, limit: int) -> float:
    if limit <= 0:
        return 0.0
    return round((used / float(limit)) * 100, 1)


def _load_recent(log_path: Path, hours: int) -> List[Dict]:
    if not log_path.exists():
        return []
    cutoff = _dt.datetime.now(_dt.timezone.utc) - _dt.timedelta(hours=hours)
    rows: List[Dict] = []
    with log_path.open("r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            try:
                data = json.loads(line)
            except json.JSONDecodeError:
                continue
            ts_raw = data.get("timestamp")
            try:
                ts = _dt.datetime.fromisoformat(ts_raw.replace("Z", "+00:00")) if ts_raw else None
            except Exception:
                ts = None
            if ts is None or ts < cutoff:
                continue
            rows.append(data)
    return rows


def render_report(tracker: UsageTracker, hours: int = 24) -> str:
    daily_used = tracker.get_daily_count()
    lifetime_used = tracker.get_lifetime_count()
    remaining = tracker.get_remaining()
    alerts = tracker.should_alert()

    recent = _load_recent(tracker.log_path, hours=hours)
    recent_total = sum(int(r.get("count", 0)) for r in recent)

    lines: List[str] = []
    lines.append("=" * 60)
    lines.append("Alter AI Usage Report")
    lines.append("=" * 60)
    lines.append("")
    lines.append("📊 Current Status:")
    lines.append(
        f"  Daily requests: {daily_used}/{tracker.daily_limit} ({_percent(daily_used, tracker.daily_limit)}%)"
    )
    lines.append(
        f"  Lifetime requests: {lifetime_used}/{tracker.lifetime_limit} ({_percent(lifetime_used, tracker.lifetime_limit)}%)"
    )
    lines.append("")
    lines.append("📈 Remaining Quota:")
    lines.append(f"  Daily remaining: {remaining['daily']}/{tracker.daily_limit}")
    lines.append(f"  Lifetime remaining: {remaining['lifetime']}/{tracker.lifetime_limit}")
    lines.append("")
    lines.append("⚠️  Alerts:")
    if alerts.get("daily"):
        lines.append(f"  - Daily quota >= {int(tracker.daily_alert_ratio * 100)}%")
    if alerts.get("lifetime"):
        lines.append(f"  - Lifetime quota >= {int(tracker.lifetime_alert_ratio * 100)}%")
    if not alerts.get("daily") and not alerts.get("lifetime"):
        lines.append("  - None")
    lines.append("")
    lines.append(f"🕑 Recent Usage (last {hours}h):")
    lines.append(f"  Requests: {recent_total}")
    return "\n".join(lines)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="Alter AI usage report")
    parser.add_argument("--hours", type=int, default=24, help="Lookback window in hours (default: 24)")
    args = parser.parse_args(argv)

    tracker = UsageTracker()
    report = render_report(tracker, hours=args.hours)
    print(report)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
