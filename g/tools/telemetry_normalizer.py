from __future__ import annotations

"""
Telemetry normalizer for LAC.

Reads JSONL files from g/telemetry and emits normalized JSONL with a common shape:
{
  "ts": "...",
  "lane": "dev_oss|dev_gmxcli|dev_codex|qa|docs|rnd|gov|background",
  "writer": "dev_worker|qa_worker|docs_worker|rnd_agent|governance|scheduler",
  "event": "success|fail|warning|info",
  "reason": "…",
  "details": {...}
}

This keeps observability consistent across sources before reporting.
"""

import json
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Iterable, List


def _parse_ts(raw: Any) -> str:
    """Return ISO timestamp string; fall back to now if missing."""
    if raw:
        try:
            if isinstance(raw, (int, float)):
                return datetime.fromtimestamp(float(raw), tz=timezone.utc).isoformat()
            if isinstance(raw, str):
                if raw.endswith("Z"):
                    raw = raw[:-1] + "+00:00"
                return datetime.fromisoformat(raw).astimezone(timezone.utc).isoformat()
        except Exception:
            pass
    return datetime.now(timezone.utc).isoformat()


def _load_jsonl(path: Path, limit: int = 5000) -> List[Dict[str, Any]]:
    rows: List[Dict[str, Any]] = []
    if not path.exists():
        return rows
    try:
        with path.open("r", encoding="utf-8") as handle:
            for i, line in enumerate(handle):
                if i >= limit:
                    break
                line = line.strip()
                if not line:
                    continue
                try:
                    rows.append(json.loads(line))
                except json.JSONDecodeError:
                    continue
    except OSError:
        return rows
    return rows


def _write_jsonl(path: Path, rows: Iterable[Dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        for row in rows:
            handle.write(json.dumps(row) + "\n")


def normalize_record(row: Dict[str, Any], source: str) -> Dict[str, Any]:
    lane = row.get("lane") or row.get("routing_hint") or "unknown"
    writer = row.get("writer") or row.get("source") or source
    status = (row.get("status") or row.get("event") or "").lower()
    if status in {"pass", "success"}:
        event = "success"
    elif status in {"warn", "warning"}:
        event = "warning"
    elif status in {"fail", "failed", "error"}:
        event = "fail"
    else:
        event = "info"

    reason = row.get("reason") or row.get("policy") or row.get("top_reason") or ""
    return {
        "ts": _parse_ts(row.get("ts") or row.get("timestamp") or row.get("time")),
        "lane": lane,
        "writer": writer,
        "event": event,
        "reason": reason,
        "details": row,
    }


def normalize_file(src: Path, dest: Path, source_label: str) -> Dict[str, Any]:
    rows = _load_jsonl(src)
    normalized = [normalize_record(r, source_label) for r in rows]
    _write_jsonl(dest, normalized)
    return {"status": "success", "count": len(normalized), "source": str(src), "dest": str(dest)}


def main() -> None:
    base_dir = Path(os.getenv("LAC_BASE_DIR") or Path.cwd())
    telemetry_dir = base_dir / "g" / "telemetry"
    out_dir = telemetry_dir / "normalized"

    targets = [
        ("dev_lane_execution.jsonl", "dev_worker"),
        ("qa_checklists.jsonl", "qa_worker"),
        ("lac_patterns.jsonl", "rnd_agent"),
        ("background_tasks.jsonl", "scheduler"),
        ("rnd_analysis.jsonl", "rnd_agent"),
        ("governance.jsonl", "governance"),
    ]

    for filename, label in targets:
        src = telemetry_dir / filename
        dest = out_dir / filename
        normalize_file(src, dest, label)


if __name__ == "__main__":
    main()
