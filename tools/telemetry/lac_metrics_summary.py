#!/usr/bin/env python3
"""
LAC metrics summary CLI.

Usage examples:
  python3 tools/telemetry/lac_metrics_summary.py
  python3 tools/telemetry/lac_metrics_summary.py --since 6h --limit 10
  python3 tools/telemetry/lac_metrics_summary.py --since 2d --json
"""

from __future__ import annotations

import argparse
import json
import os
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple


@dataclass
class MetricsEvent:
    ts: datetime
    wo_id: str
    status: str
    duration_ms: Optional[int]
    queue_depth: Optional[int]


def resolve_root() -> Path:
    env_root = os.environ.get("LUKA_SOT") or os.environ.get("LUKA_ROOT")
    if env_root:
        return Path(env_root).expanduser().resolve()
    return Path.home().joinpath("02luka").resolve()


def parse_since(value: str) -> Optional[timedelta]:
    if value.strip().lower() == "all":
        return None
    value = value.strip().lower()
    if len(value) < 2:
        raise ValueError("--since must be like 24h, 7d, 60m, or 3600s")
    num_part = value[:-1]
    unit = value[-1]
    if not num_part.isdigit() or unit not in {"s", "m", "h", "d"}:
        raise ValueError("--since must be like 24h, 7d, 60m, or 3600s")
    amount = int(num_part)
    if unit == "s":
        return timedelta(seconds=amount)
    if unit == "m":
        return timedelta(minutes=amount)
    if unit == "h":
        return timedelta(hours=amount)
    if unit == "d":
        return timedelta(days=amount)
    raise ValueError("unsupported --since unit")


def parse_ts(value: str) -> Optional[datetime]:
    try:
        return datetime.strptime(value, "%Y-%m-%dT%H:%M:%S%z")
    except Exception:
        return None


def load_events(path: Path) -> List[MetricsEvent]:
    events: List[MetricsEvent] = []
    if not path.exists():
        return events
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except Exception:
        return events

    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            payload = json.loads(line)
        except Exception:
            continue
        ts_raw = payload.get("ts")
        ts = parse_ts(str(ts_raw)) if ts_raw else None
        if not ts:
            continue
        events.append(
            MetricsEvent(
                ts=ts,
                wo_id=str(payload.get("wo_id", "")),
                status=str(payload.get("status", "")),
                duration_ms=_coerce_int(payload.get("duration_ms")),
                queue_depth=_coerce_int(payload.get("queue_depth")),
            )
        )
    return events


def _coerce_int(value: Any) -> Optional[int]:
    if value is None:
        return None
    try:
        return int(value)
    except Exception:
        return None


def percentile(values: List[int], pct: float) -> Optional[int]:
    if not values:
        return None
    values_sorted = sorted(values)
    if len(values_sorted) == 1:
        return values_sorted[0]
    idx = int(round(pct * (len(values_sorted) - 1)))
    return values_sorted[max(0, min(idx, len(values_sorted) - 1))]


def summarize(events: List[MetricsEvent], since_delta: Optional[timedelta], limit: int) -> Dict[str, Any]:
    totals = {
        "completed": sum(1 for e in events if e.status == "completed"),
        "error": sum(1 for e in events if e.status == "error"),
        "total": len(events),
    }

    now = datetime.now(timezone.utc)
    if since_delta is None:
        window_events = list(events)
        window_start = None
    else:
        window_start = now - since_delta
        window_events = [e for e in events if e.ts >= window_start]

    window_counts = {
        "total": len(window_events),
        "completed": sum(1 for e in window_events if e.status == "completed"),
        "error": sum(1 for e in window_events if e.status == "error"),
    }
    if window_counts["total"]:
        error_rate = window_counts["error"] / window_counts["total"]
    else:
        error_rate = None

    durations = [e.duration_ms for e in window_events if e.duration_ms is not None]
    durations_int = [d for d in durations if d is not None]
    duration_stats = {
        "avg": int(sum(durations_int) / len(durations_int)) if durations_int else None,
        "p50": percentile(durations_int, 0.50) if durations_int else None,
        "p95": percentile(durations_int, 0.95) if durations_int else None,
    }

    depths = [e.queue_depth for e in window_events if e.queue_depth is not None]
    depth_stats = {
        "min": min(depths) if depths else None,
        "avg": int(sum(depths) / len(depths)) if depths else None,
        "max": max(depths) if depths else None,
    }

    events_sorted = sorted(window_events, key=lambda e: e.ts)
    last_events = events_sorted[-limit:] if limit > 0 else []

    return {
        "totals": totals,
        "window": {
            "since": None if since_delta is None else _format_timedelta(since_delta),
            "start": window_start.isoformat() if window_start else None,
            "end": now.isoformat(),
            "counts": window_counts,
            "error_rate": error_rate,
        },
        "duration_ms": duration_stats,
        "queue_depth": depth_stats,
        "last_events": [
            {
                "ts": e.ts.isoformat(),
                "wo_id": e.wo_id,
                "status": e.status,
                "duration_ms": e.duration_ms,
                "queue_depth": e.queue_depth,
            }
            for e in last_events
        ],
    }


def _format_timedelta(delta: timedelta) -> str:
    seconds = int(delta.total_seconds())
    if seconds % 86400 == 0:
        return f"{seconds // 86400}d"
    if seconds % 3600 == 0:
        return f"{seconds // 3600}h"
    if seconds % 60 == 0:
        return f"{seconds // 60}m"
    return f"{seconds}s"


def render_text(summary: Dict[str, Any], no_data: bool) -> str:
    if no_data:
        return "no data"

    lines: List[str] = []
    totals = summary["totals"]
    window = summary["window"]
    duration = summary["duration_ms"]
    depth = summary["queue_depth"]

    lines.append("LAC Metrics Summary")
    lines.append("====================")
    lines.append(f"Totals: completed={totals['completed']} error={totals['error']} total={totals['total']}")

    window_counts = window["counts"]
    if window["since"]:
        lines.append(
            f"Window ({window['since']}): total={window_counts['total']} completed={window_counts['completed']} "
            f"error={window_counts['error']} error_rate={_format_rate(window['error_rate'])}"
        )
    else:
        lines.append(
            f"Window (all): total={window_counts['total']} completed={window_counts['completed']} "
            f"error={window_counts['error']} error_rate={_format_rate(window['error_rate'])}"
        )

    lines.append(
        "Duration ms: avg={avg} p50={p50} p95={p95}".format(
            avg=_format_int(duration["avg"]),
            p50=_format_int(duration["p50"]),
            p95=_format_int(duration["p95"]),
        )
    )
    lines.append(
        "Queue depth: min={min} avg={avg} max={max}".format(
            min=_format_int(depth["min"]),
            avg=_format_int(depth["avg"]),
            max=_format_int(depth["max"]),
        )
    )

    lines.append("")
    lines.append("Last events:")
    lines.append("ts\tstatus\tduration_ms\tqueue_depth\two_id")
    for event in summary["last_events"]:
        lines.append(
            f"{event['ts']}\t{event['status']}\t"
            f"{_format_int(event['duration_ms'])}\t{_format_int(event['queue_depth'])}\t{event['wo_id']}"
        )

    return "\n".join(lines)


def _format_int(value: Optional[int]) -> str:
    return "-" if value is None else str(value)


def _format_rate(value: Optional[float]) -> str:
    if value is None:
        return "-"
    return f"{value * 100:.1f}%"


def main() -> int:
    parser = argparse.ArgumentParser(description="Summarize LAC metrics JSONL")
    parser.add_argument("--since", default="24h", help="Time window, e.g. 24h, 7d, 60m, or 'all'")
    parser.add_argument("--limit", type=int, default=20, help="Last N events to show")
    parser.add_argument("--json", action="store_true", help="Output JSON summary")

    args = parser.parse_args()

    root = resolve_root()
    metrics_path = root / "g/telemetry/lac_metrics.jsonl"

    try:
        since_delta = parse_since(args.since)
    except ValueError as exc:
        print(str(exc))
        return 2

    events = load_events(metrics_path)
    if not events:
        if args.json:
            print(json.dumps({"status": "no_data", "path": str(metrics_path)}))
        else:
            print("no data")
        return 0

    summary = summarize(events, since_delta, max(args.limit, 0))
    if args.json:
        print(json.dumps(summary))
    else:
        print(render_text(summary, no_data=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
