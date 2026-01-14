#!/usr/bin/env python3
"""
LAC daily telemetry MLS ingestion.

Usage examples:
  python3 tools/telemetry/lac_metrics_mls_ingest.py
  python3 tools/telemetry/lac_metrics_mls_ingest.py --input /Users/icmini/02luka_ws/g/telemetry/lac_metrics_summary_latest.json

Daily run: invoke after the exporter updates lac_metrics_summary_latest.json.

Example MLS entry (JSONL):
  {"ts":"2026-01-14T23:46:34.666638+07:00","type":"pattern","title":"LAC Daily Telemetry Summary","summary":"LAC daily telemetry summary. payload={...}","source":{"producer":"codex","context":"local","repo":"Ic1558/02luka","run_id":null,"workflow":null,"sha":null,"artifact":"lac_metrics_exporter","artifact_path":"/Users/icmini/02luka_ws/g/telemetry/lac_metrics_summary_latest.json"},"links":{"followup_id":null,"wo_id":null},"tags":["lac","telemetry","daily","lac_metrics_exporter"],"author":"codex","confidence":0.7}
"""

from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

DEFAULT_INPUT = Path("/Users/icmini/02luka_ws/g/telemetry/lac_metrics_summary_latest.json")
DEFAULT_REPO = "Ic1558/02luka"
TITLE = "LAC Daily Telemetry Summary"


@dataclass
class Insight:
    type: str
    severity: str
    message: str
    evidence: Dict[str, Any]

    def as_dict(self) -> Dict[str, Any]:
        return {
            "type": self.type,
            "severity": self.severity,
            "message": self.message,
            "evidence": self.evidence,
        }


def load_summary(path: Path) -> Optional[Dict[str, Any]]:
    if not path.exists():
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return None
    if not isinstance(data, dict):
        return None
    return data


def parse_generated_at(value: Any) -> Optional[datetime]:
    if not isinstance(value, str) or not value.strip():
        return None
    try:
        return datetime.fromisoformat(value)
    except Exception:
        return None


def coerce_number(value: Any) -> Optional[float]:
    if value is None:
        return None
    try:
        return float(value)
    except Exception:
        return None


def derive_insights(summary: Dict[str, Any]) -> List[Insight]:
    insights: List[Insight] = []

    duration = summary.get("duration_ms") or {}
    p95_ms = coerce_number(duration.get("p95_ms"))
    if p95_ms is not None and p95_ms > 500:
        insights.append(
            Insight(
                type="slow_p95",
                severity="warning",
                message=f"p95 latency elevated: {int(p95_ms)}ms",
                evidence={"p95_ms": int(p95_ms)},
            )
        )

    error_rate = coerce_number(summary.get("window_error_rate_pct"))
    if error_rate is not None and error_rate > 0:
        insights.append(
            Insight(
                type="error_detected",
                severity="warning",
                message=f"errors detected in window: {error_rate:.2f}%",
                evidence={"window_error_rate_pct": error_rate},
            )
        )

    queue_depth = summary.get("queue_depth") or {}
    queue_max = coerce_number(queue_depth.get("max"))
    if queue_max is not None and queue_max > 0:
        insights.append(
            Insight(
                type="queue_spike",
                severity="warning",
                message=f"queue depth spike: max={int(queue_max)}",
                evidence={"queue_depth_max": int(queue_max)},
            )
        )

    if not insights:
        insights.append(
            Insight(
                type="healthy",
                severity="info",
                message="no anomalies detected",
                evidence={
                    "window_error_rate_pct": coerce_number(summary.get("window_error_rate_pct")) or 0.0,
                    "p95_ms": int(p95_ms) if p95_ms is not None else None,
                    "queue_depth_max": int(queue_max) if queue_max is not None else None,
                },
            )
        )

    return insights


def build_payload(summary: Dict[str, Any], insights: List[Insight]) -> Dict[str, Any]:
    totals = summary.get("totals") or {}
    duration = summary.get("duration_ms") or {}
    queue_depth = summary.get("queue_depth") or {}

    return {
        "source": "lac_metrics_exporter",
        "totals": {
            "completed": totals.get("completed"),
            "error": totals.get("error"),
            "total": totals.get("total"),
        },
        "window_error_rate_pct": summary.get("window_error_rate_pct"),
        "duration_ms": {
            "avg_ms": duration.get("avg_ms"),
            "p95_ms": duration.get("p95_ms"),
        },
        "queue_depth": {
            "avg": queue_depth.get("avg"),
            "max": queue_depth.get("max"),
        },
        "insights": [insight.as_dict() for insight in insights],
    }


def ledger_path_for_date(root: Path, date_value: datetime) -> Path:
    day = date_value.date().isoformat()
    return root / "mls" / "ledger" / f"{day}.jsonl"


def already_ingested(ledger_path: Path, generated_at: str) -> bool:
    if not ledger_path.exists():
        return False
    try:
        lines = ledger_path.read_text(encoding="utf-8").splitlines()
    except Exception:
        return False
    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            event = json.loads(line)
        except Exception:
            continue
        if event.get("title") == TITLE and event.get("ts") == generated_at:
            return True
    return False


def write_mls_entry(ledger_path: Path, entry: Dict[str, Any]) -> None:
    ledger_path.parent.mkdir(parents=True, exist_ok=True)
    with ledger_path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(entry, ensure_ascii=True) + "\n")


def notify_if_needed(base_root: Path, generated_at: str, insights: List[Insight], summary: Dict[str, Any]) -> None:
    if not insights:
        return
    if all(insight.type == "healthy" for insight in insights):
        return

    insight_types = sorted({insight.type for insight in insights})
    duration = summary.get("duration_ms") or {}
    queue_depth = summary.get("queue_depth") or {}
    error_rate = summary.get("window_error_rate_pct")

    message = (
        f"LAC telemetry alert ({generated_at.split('T')[0]}): "
        f"insights={','.join(insight_types)} "
        f"p95_ms={duration.get('p95_ms')} "
        f"error_rate_pct={error_rate} "
        f"queue_max={queue_depth.get('max')}"
    )

    rd_dir = base_root / "bridge" / "inbox" / "rd"
    try:
        rd_dir.mkdir(parents=True, exist_ok=True)
        safe_ts = generated_at.replace(":", "").replace("+", "").replace(".", "")
        notification_path = rd_dir / f"LAC-telemetry-alert-{safe_ts}.json"
        if notification_path.exists():
            return

        payload = {
            "task": "review_lac_telemetry",
            "date": generated_at.split("T")[0],
            "insight_types": insight_types,
            "summary": message,
            "p95_ms": duration.get("p95_ms"),
            "error_rate_pct": error_rate,
            "queue_depth_max": queue_depth.get("max"),
            "source": "lac_metrics_exporter",
            "generated_at": generated_at,
            "priority": "P3",
            "auto_approve": True,
        }
        notification_path.write_text(json.dumps(payload, ensure_ascii=True), encoding="utf-8")
    except Exception as exc:
        print(f"alert skipped: {exc}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Ingest LAC telemetry summary into MLS ledger")
    parser.add_argument("--input", default=str(DEFAULT_INPUT), help="Path to lac_metrics_summary_latest.json")
    args = parser.parse_args()

    input_path = Path(args.input)
    summary = load_summary(input_path)
    if not summary:
        print("no data")
        return 0

    generated_at = summary.get("generated_at")
    parsed_ts = parse_generated_at(generated_at)
    if not generated_at or not parsed_ts:
        print("no data")
        return 0

    base_root = input_path.parents[2] if len(input_path.parents) >= 3 else Path("/Users/icmini/02luka_ws")
    ledger_path = ledger_path_for_date(base_root, parsed_ts)
    if already_ingested(ledger_path, generated_at):
        print("already ingested")
        return 0

    insights = derive_insights(summary)
    payload = build_payload(summary, insights)
    summary_text = f"LAC daily telemetry summary. payload={json.dumps(payload, ensure_ascii=True)}"

    tags = ["lac", "telemetry", "daily", "lac_metrics_exporter"]
    tags.extend([insight.type for insight in insights if insight.type != "healthy"])
    tags = sorted({tag for tag in tags if tag})

    entry = {
        "ts": generated_at,
        "type": "pattern",
        "title": TITLE,
        "summary": summary_text,
        "source": {
            "producer": "codex",
            "context": "local",
            "repo": DEFAULT_REPO,
            "run_id": None,
            "workflow": None,
            "sha": None,
            "artifact": "lac_metrics_exporter",
            "artifact_path": str(input_path),
        },
        "links": {
            "followup_id": None,
            "wo_id": None,
        },
        "tags": tags,
        "author": "codex",
        "confidence": 0.7,
    }

    write_mls_entry(ledger_path, entry)
    notify_if_needed(base_root, generated_at, insights, summary)
    print(f"ingested {generated_at}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
