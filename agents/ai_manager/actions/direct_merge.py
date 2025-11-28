"""
DIRECT_MERGE action for AI Manager.
"""

from __future__ import annotations

import json
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List

from g.tools.lac_telemetry import build_event, log_event
import time


def _completion_log_path() -> Path:
    override = os.getenv("LAC_COMPLETIONS_LOG")
    if override:
        return Path(override).resolve()
    return Path("g/ledger/autonomous_completions.jsonl")


def append_jsonl(path: Path, record: Dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(record) + "\n")


def direct_merge(wo: Dict, files_touched: List[str]) -> Dict:
    """
    Execute direct merge without CLC involvement.
    Called when: self_apply=true AND QA_PASSED AND complexity=simple
    """
    start = time.monotonic()
    completion_record = {
        "wo_id": wo["wo_id"],
        "merge_type": "DIRECT",
        "files": files_touched,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "used_clc": False,
        "used_paid": False,
    }

    append_jsonl(_completion_log_path(), completion_record)

    wo["status"] = "COMPLETE"
    wo["completed_at"] = completion_record["timestamp"]

    duration_ms = int((time.monotonic() - start) * 1000)
    try:
        event = build_event(
            event_type="MERGE_COMPLETED",
            wo_id=wo.get("wo_id", "unknown"),
            lane="direct_merge",
            status="success",
            duration_ms=duration_ms,
            paid=bool(wo.get("requires_paid_lane", False)),
            extra={"files_touched": files_touched},
        )
        log_event(event)
    except Exception:
        pass

    return {
        "status": "success",
        "merge_type": "DIRECT",
        "wo_id": wo["wo_id"],
        "files_touched": files_touched,
    }


__all__ = ["direct_merge", "append_jsonl"]
