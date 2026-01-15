#!/usr/bin/env python3
"""Core intake brief derived from g/core_state/latest.json."""

from __future__ import annotations

import argparse
import json
import os
import re
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional


RECENT_WINDOW = timedelta(minutes=60)
RECENT_LIMIT_PER_LANE = 3
STOPWORDS = {
    "a",
    "an",
    "and",
    "the",
    "to",
    "for",
    "of",
    "in",
    "on",
    "with",
    "without",
    "from",
    "at",
    "by",
    "is",
    "are",
    "be",
    "was",
    "were",
    "it",
    "this",
    "that",
    "as",
}


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def _latest_path() -> Path:
    return _repo_root() / "g" / "core_state" / "latest.json"


def _work_notes_path() -> Path:
    ws_root = os.environ.get("LUKA_WS_ROOT")
    if ws_root:
        return Path(ws_root).expanduser().resolve() / "g" / "core_state" / "work_notes.jsonl"
    return _repo_root() / "g" / "core_state" / "work_notes.jsonl"


def _load_latest() -> Optional[Dict[str, Any]]:
    path = _latest_path()
    if not path.exists():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return None


def _parse_ts(value: Optional[str]) -> Optional[datetime]:
    if not value:
        return None
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=datetime.now().astimezone().tzinfo)
    return parsed.astimezone(timezone.utc)


def _normalize_keywords(text: str) -> List[str]:
    tokens = re.findall(r"[a-z0-9]+", text.lower())
    keywords = [t for t in tokens if len(t) > 2 and t not in STOPWORDS]
    return sorted(set(keywords))


def _task_prefix(task_id: str) -> str:
    for sep in ("-", "_", "."):
        if sep in task_id:
            return task_id.split(sep, 1)[0]
    return task_id[:8]


def _extract_work_notes() -> List[Dict[str, Any]]:
    cleaned: List[Dict[str, Any]] = []
    path = _work_notes_path()
    if not path.exists():
        return []
    try:
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    except Exception:
        return []
    for raw in lines:
        try:
            note = json.loads(raw)
        except Exception:
            continue
        if not isinstance(note, dict):
            continue
        timestamp = note.get("timestamp")
        parsed = _parse_ts(timestamp)
        cleaned.append({**note, "_parsed_ts": parsed})
    return cleaned


def _recent_notes(notes: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    now = datetime.now(timezone.utc)
    return [
        note for note in notes if note.get("_parsed_ts") and now - note["_parsed_ts"] <= RECENT_WINDOW
    ]


def _notes_by_lane(notes: List[Dict[str, Any]]) -> Dict[str, List[Dict[str, Any]]]:
    lanes: Dict[str, List[Dict[str, Any]]] = {}
    for note in notes:
        lane = note.get("lane") or "unknown"
        lanes.setdefault(lane, []).append(note)
    for lane in lanes:
        lanes[lane].sort(key=lambda n: n.get("_parsed_ts") or datetime.min, reverse=True)
        lanes[lane] = lanes[lane][:RECENT_LIMIT_PER_LANE]
    return lanes


def _find_duplicate(
    recent: List[Dict[str, Any]],
    task_id: Optional[str],
    summary: Optional[str],
) -> Optional[Dict[str, Any]]:
    if not recent:
        return None
    summary_sig = _normalize_keywords(summary or "")
    prefix = _task_prefix(task_id) if task_id else None
    for note in recent:
        note_task = note.get("task_id")
        note_summary = note.get("short_summary", "")
        if prefix and note_task and _task_prefix(str(note_task)) == prefix:
            return note
        if summary_sig and summary_sig == _normalize_keywords(str(note_summary)):
            return note
    return None


def build_intake(
    task_id: Optional[str] = None,
    summary: Optional[str] = None,
) -> Dict[str, Any]:
    latest = _load_latest()
    if not latest:
        return {
            "status": "no_data",
            "reason": "latest.json missing or unreadable",
            "recent_work": {},
            "duplicate": None,
        }

    git_clean = latest.get("git_status", {}).get("clean")
    guard_running = latest.get("mls_symlink_guard", {}).get("running")
    processes = latest.get("processes", {})

    notes = _extract_work_notes()
    recent = _recent_notes(notes)
    per_lane = _notes_by_lane(recent)
    duplicate = _find_duplicate(recent, task_id, summary)

    return {
        "status": "ok",
        "timestamp": latest.get("timestamp", {}).get("local"),
        "repo": latest.get("repo", {}),
        "git_clean": git_clean,
        "guard_running": guard_running,
        "processes": processes,
        "lac_queues": latest.get("lac_queues", {}),
        "recent_work": per_lane,
        "duplicate": duplicate,
    }


def render_text(payload: Dict[str, Any]) -> str:
    lines: List[str] = ["Core Intake Brief"]
    if payload.get("status") != "ok":
        lines.extend(
            [
                f"Status: {payload.get('status')}",
                f"Reason: {payload.get('reason')}",
                "Updated: -",
                "Repo: -",
                "Branch: -",
                "HEAD: -",
                "Git clean: -",
                "MLS guard: -",
                "Processes: -",
                "LAC queues: -",
                "Recent lanes: -",
                "Recent work: none",
                "Duplicate hint: -",
            ]
        )
        return "\n".join(lines)

    repo = payload.get("repo", {})
    branch = repo.get("branch")
    head = repo.get("head")
    head_short = head[:8] if isinstance(head, str) else "-"
    lines.extend(
        [
            f"Updated: {payload.get('timestamp')}",
            f"Repo: {repo.get('root')}",
            f"Branch: {branch}",
            f"HEAD: {head_short}",
            f"Git clean: {payload.get('git_clean')}",
            f"MLS guard: {payload.get('guard_running')}",
        ]
    )

    processes = payload.get("processes", {})
    if isinstance(processes, dict):
        def status_for(key: str) -> str:
            proc = processes.get(key, {})
            return "on" if isinstance(proc, dict) and proc.get("pid") else "off"

        lines.append(
            "Processes: "
            + f"Mary={status_for('mary.py')} "
            + f"Router={status_for('gateway_router')} "
            + f"LAC={status_for('lac_manager')}"
        )

    queues = payload.get("lac_queues", {})
    if isinstance(queues, dict):
        inbox = queues.get("lac_inbox", {}).get("file_count", 0) if isinstance(queues.get("lac_inbox"), dict) else 0
        processing = queues.get("lac_processing", {}).get("file_count", 0) if isinstance(queues.get("lac_processing"), dict) else 0
        lines.append(f"LAC queues: inbox={inbox} processing={processing}")
    else:
        lines.append("LAC queues: -")

    recent = payload.get("recent_work", {})
    lines.append(f"Recent lanes: {len(recent) if isinstance(recent, dict) else 0}")
    if not recent:
        lines.append("Recent work: none")
    else:
        lines.append("Recent work (last 60m):")
        for lane in sorted(recent.keys()):
            items = recent.get(lane, [])
            if not isinstance(items, list):
                continue
            for item in items:
                ts = item.get("timestamp") or "-"
                summary = item.get("short_summary") or "-"
                status = item.get("status") or "-"
                lines.append(f"- {lane} {ts} {status} {summary}")

    duplicate = payload.get("duplicate")
    if duplicate:
        lines.append("Potential duplicate: recent similar work detected")
    else:
        lines.append("Duplicate hint: none")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="Core intake brief from latest.json")
    parser.add_argument("--json", action="store_true", help="Output JSON payload")
    parser.add_argument("--task-id", default=None, help="Optional task id for duplicate check")
    parser.add_argument("--summary", default=None, help="Optional task summary for duplicate check")
    args = parser.parse_args()

    payload = build_intake(task_id=args.task_id, summary=args.summary)
    if args.json:
        print(json.dumps(payload, indent=2, sort_keys=True))
        return 0
    print(render_text(payload))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
