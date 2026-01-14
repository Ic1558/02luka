#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import os
import statistics
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

DEFAULT_ROOT = Path(os.environ.get("LUKA_SOT") or os.environ.get("LUKA_ROOT") or os.path.expanduser("~/02luka")).resolve()

def _parse_iso(ts: str) -> Optional[datetime]:
    """
    Accepts:
      - 2026-01-14T03:11:23+0700
      - 2026-01-14T03:42:50+07:00
      - 2026-01-13T22:19:28Z
    Returns timezone-aware datetime or None.
    """
    s = (ts or "").strip()
    if not s:
        return None
    try:
        if s.endswith("Z"):
            return datetime.fromisoformat(s.replace("Z", "+00:00"))
        # handle +0700 (no colon)
        if len(s) >= 5 and (s[-5] in ["+", "-"]) and s[-2:].isdigit() and s[-4:-2].isdigit() and s[-3] != ":":
            # ...+0700 -> ...+07:00
            s = s[:-5] + s[-5:-2] + ":" + s[-2:]
        return datetime.fromisoformat(s)
    except Exception:
        return None

def _now_local() -> datetime:
    return datetime.now().astimezone()

def _percentile(values: List[int], p: float) -> int:
    if not values:
        return 0
    if len(values) == 1:
        return int(values[0])
    xs = sorted(values)
    # nearest-rank with interpolation
    k = (len(xs) - 1) * (p / 100.0)
    f = math.floor(k)
    c = math.ceil(k)
    if f == c:
        return int(xs[int(k)])
    d0 = xs[f] * (c - k)
    d1 = xs[c] * (k - f)
    return int(round(d0 + d1))

@dataclass
class MetricEvent:
    ts: datetime
    wo_id: str
    status: str
    duration_ms: int
    queue_depth: int
    raw: Dict[str, Any]

def load_events(metrics_path: Path) -> List[MetricEvent]:
    events: List[MetricEvent] = []
    with metrics_path.open("r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except Exception:
                continue
            ts = _parse_iso(str(obj.get("ts", ""))) or None
            if ts is None:
                continue
            wo_id = str(obj.get("wo_id", "UNKNOWN"))
            status = str(obj.get("status", "unknown"))
            try:
                duration_ms = int(obj.get("duration_ms", 0))
            except Exception:
                duration_ms = 0
            try:
                queue_depth = int(obj.get("queue_depth", 0))
            except Exception:
                queue_depth = 0
            events.append(MetricEvent(ts=ts, wo_id=wo_id, status=status, duration_ms=duration_ms, queue_depth=queue_depth, raw=obj))
    # sort chronological
    events.sort(key=lambda e: e.ts)
    return events

def summarize(events: List[MetricEvent], since: timedelta, limit: int) -> Dict[str, Any]:
    now = _now_local()
    cutoff = now - since
    window = [e for e in events if e.ts >= cutoff]

    def counts(evts: List[MetricEvent]) -> Dict[str, int]:
        c_completed = sum(1 for e in evts if e.status == "completed")
        c_error = sum(1 for e in evts if e.status == "error")
        return {"completed": c_completed, "error": c_error, "total": len(evts)}

    totals = counts(events)
    w = counts(window)

    durations = [max(0, int(e.duration_ms)) for e in window]
    qdepths = [int(e.queue_depth) for e in window]

    duration_stats = {
        "avg_ms": int(round(statistics.mean(durations))) if durations else 0,
        "p50_ms": _percentile(durations, 50),
        "p95_ms": _percentile(durations, 95),
        "min_ms": min(durations) if durations else 0,
        "max_ms": max(durations) if durations else 0,
    }

    queue_stats = {
        "min": min(qdepths) if qdepths else 0,
        "avg": float(statistics.mean(qdepths)) if qdepths else 0.0,
        "max": max(qdepths) if qdepths else 0,
    }

    last_events = list(reversed(events))[:max(0, limit)]
    last_events_out = [
        {
            "ts": e.ts.isoformat(),
            "status": e.status,
            "duration_ms": e.duration_ms,
            "queue_depth": e.queue_depth,
            "wo_id": e.wo_id,
        }
        for e in last_events
    ]

    err_rate = (w["error"] / w["total"] * 100.0) if w["total"] else 0.0

    return {
        "generated_at": now.isoformat(),
        "window": {
            "since_seconds": int(since.total_seconds()),
            "cutoff": cutoff.isoformat(),
        },
        "totals": totals,
        "window_counts": w,
        "window_error_rate_pct": round(err_rate, 3),
        "duration_ms": duration_stats,
        "queue_depth": queue_stats,
        "last_events": last_events_out,
    }

def render_md(summary_obj: Dict[str, Any]) -> str:
    gen = summary_obj.get("generated_at", "")
    totals = summary_obj.get("totals", {})
    w = summary_obj.get("window_counts", {})
    err = summary_obj.get("window_error_rate_pct", 0.0)
    dur = summary_obj.get("duration_ms", {})
    qd = summary_obj.get("queue_depth", {})
    last = summary_obj.get("last_events", [])

    lines: List[str] = []
    lines.append("# LAC Metrics Summary")
    lines.append("")
    lines.append(f"- Generated: `{gen}`")
    lines.append("")
    lines.append("## Totals")
    lines.append(f"- completed: **{totals.get('completed', 0)}**")
    lines.append(f"- error: **{totals.get('error', 0)}**")
    lines.append(f"- total: **{totals.get('total', 0)}**")
    lines.append("")
    lines.append("## Window")
    lines.append(f"- completed: **{w.get('completed', 0)}**")
    lines.append(f"- error: **{w.get('error', 0)}**")
    lines.append(f"- total: **{w.get('total', 0)}**")
    lines.append(f"- error_rate: **{err}%**")
    lines.append("")
    lines.append("## Duration (ms) — Window")
    lines.append(f"- avg: **{dur.get('avg_ms', 0)}**")
    lines.append(f"- p50: **{dur.get('p50_ms', 0)}**")
    lines.append(f"- p95: **{dur.get('p95_ms', 0)}**")
    lines.append(f"- min/max: **{dur.get('min_ms', 0)} / {dur.get('max_ms', 0)}**")
    lines.append("")
    lines.append("## Queue Depth — Window")
    lines.append(f"- min/avg/max: **{qd.get('min', 0)} / {qd.get('avg', 0):.2f} / {qd.get('max', 0)}**")
    lines.append("")
    lines.append("## Last Events")
    lines.append("")
    lines.append("| ts | status | duration_ms | queue_depth | wo_id |")
    lines.append("|---|---:|---:|---:|---|")
    for e in last:
        lines.append(f"| `{e.get('ts','')}` | `{e.get('status','')}` | {e.get('duration_ms',0)} | {e.get('queue_depth',0)} | `{e.get('wo_id','')}` |")
    lines.append("")
    return "\n".join(lines)

def main() -> int:
    ap = argparse.ArgumentParser(description="Export LAC metrics summary to JSON + Markdown.")
    ap.add_argument("--root", default=str(DEFAULT_ROOT), help="02luka root (default: env LUKA_SOT/LUKA_ROOT or ~/02luka)")
    ap.add_argument("--since", default="24h", help="window, e.g. 24h, 1h, 7d (default: 24h)")
    ap.add_argument("--limit", type=int, default=20, help="last events limit (default: 20)")
    ap.add_argument("--metrics", default="g/telemetry/lac_metrics.jsonl", help="metrics jsonl path relative to root")
    ap.add_argument("--out-json", default="g/telemetry/lac_metrics_summary_latest.json", help="output json path relative to root")
    ap.add_argument("--out-md", default="g/telemetry/lac_metrics_summary_latest.md", help="output md path relative to root")
    ap.add_argument("--print", action="store_true", help="also print summary to stdout (md)")
    args = ap.parse_args()

    root = Path(args.root).expanduser().resolve()

    def parse_since(s: str) -> timedelta:
        t = s.strip().lower()
        if t.endswith("h"):
            return timedelta(hours=int(t[:-1]))
        if t.endswith("d"):
            return timedelta(days=int(t[:-1]))
        if t.endswith("m"):
            return timedelta(minutes=int(t[:-1]))
        # fallback seconds
        return timedelta(seconds=int(t))

    since_td = parse_since(args.since)

    metrics_path = (root / args.metrics).resolve()
    out_json = (root / args.out_json).resolve()
    out_md = (root / args.out_md).resolve()

    if not metrics_path.exists():
        raise FileNotFoundError(f"metrics not found: {metrics_path}")

    events = load_events(metrics_path)
    s = summarize(events, since=since_td, limit=args.limit)

    out_json.parent.mkdir(parents=True, exist_ok=True)
    out_md.parent.mkdir(parents=True, exist_ok=True)

    out_json.write_text(json.dumps(s, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    out_md.write_text(render_md(s), encoding="utf-8")

    if args.print:
        print(render_md(s))

    return 0

if __name__ == "__main__":
    raise SystemExit(main())
