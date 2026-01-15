#!/usr/bin/env python3
"""
Core Intake CLI & System State View
-----------------------------------
Canonical entry point for Agents and Humans to check system state
and declare new work (Intake).

- Reads Snapshot: g/core_state/latest.json
- Reads Journal:  g/core_state/work_notes.jsonl (tail)
- Writes Journal: g/core_state/work_notes.jsonl (via atomic append)

Usage:
  core_intake.py --json
  core_intake.py --task-id "WO-123" --summary "fix stuff"
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

# Constants
RECENT_WINDOW = timedelta(minutes=60)
RECENT_LIMIT_PER_LANE = 3
STOPWORDS = {
    "a", "an", "and", "the", "to", "for", "of", "in", "on",
    "with", "without", "from", "at", "by", "is", "are", "be",
    "was", "were", "it", "this", "that", "as"
}

def _repo_root() -> Path:
    # Always resolve relative to this script location in g/tools
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
    
    # Try Digest First (Fast Path)
    base_path = _work_notes_path()
    digest_path = base_path.with_name("work_notes_digest.jsonl")
    
    target_path = base_path
    if digest_path.exists():
        target_path = digest_path
    elif not base_path.exists():
        return []

    try:
        lines = target_path.read_text(encoding="utf-8", errors="replace").splitlines()
        # Fallback: If digest is empty but journal is not, maybe force read journal?
        # For now, trust the digest path if it exists.
    except Exception:
        # If digest read fails, try journal
        if target_path == digest_path and base_path.exists():
            try:
                lines = base_path.read_text(encoding="utf-8", errors="replace").splitlines()
                # Tail 200 if reading full journal fallback
                lines = lines[-200:]
            except Exception:
                return []
        else:
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
        # Keep limit and strip internal _parsed_ts
        cleaned_lane = []
        for note in lanes[lane][:RECENT_LIMIT_PER_LANE]:
            n_copy = note.copy()
            n_copy.pop("_parsed_ts", None)
            cleaned_lane.append(n_copy)
        lanes[lane] = cleaned_lane
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
    
    # Clean duplicate if found
    if duplicate:
        duplicate = duplicate.copy()
        duplicate.pop("_parsed_ts", None)

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
        lines.extend([f"Status: {payload.get('status')}", f"Reason: {payload.get('reason')}"])
        return "\n".join(lines)

    repo = payload.get("repo", {})
    branch = repo.get("branch")
    head = repo.get("head")
    head_short = head[:8] if isinstance(head, str) else "-"
    lines.extend([
        f"Updated: {payload.get('timestamp')}",
        f"Repo: {repo.get('root')}",
        f"Branch: {branch}",
        f"HEAD: {head_short}",
        f"Git clean: {payload.get('git_clean')}",
        f"MLS guard: {payload.get('guard_running')}",
    ])

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
        lines.append(f"Potential duplicate: recent similar work detected ({duplicate.get('task_id')}: {duplicate.get('short_summary')})")
    else:
        lines.append("Duplicate hint: none")
    return "\n".join(lines)

# --- CLI Integration ---

def log_work_note_via_writer(lane: str, task_id: str, summary: str, status: str) -> bool:
    # Dynamically import to avoid circular dependencies if possible, or just standard import
    # Assuming bridge.lac.writer is available in the path
    sys.path.append(str(_repo_root()))
    try:
        from bridge.lac.writer import write_work_note
        return write_work_note(lane=lane, task_id=task_id, short_summary=summary, status=status)
    except ImportError:
        sys.stderr.write("Error: Could not import bridge.lac.writer\n")
        return False

def main() -> int:
    parser = argparse.ArgumentParser(description="Core Intake CLI & System State View")
    parser.add_argument("--json", action="store_true", help="Output JSON struct instead of text")
    parser.add_argument("--task-id", help="Task ID to intake (logs work note)")
    parser.add_argument("--summary", help="Short summary of the task")
    parser.add_argument("--lane", default="dev", help="Lane for the task (default: dev)")
    
    args = parser.parse_args()

    # 1. Build View (Snapshot + Journal)
    data = build_intake(task_id=args.task_id, summary=args.summary)
    
    # 2. Intake Action (if requested)
    logged = False
    if args.task_id and args.summary:
        if args.summary.strip():
            logged = log_work_note_via_writer(
                lane=args.lane,
                task_id=args.task_id,
                summary=f"INTAKE: {args.summary}",
                status="pending"
            )
            data["intake_logged"] = logged
        else:
            sys.stderr.write("Error: Summary cannot be empty.\n")
            return 1

    # 3. Output
    if args.json:
        print(json.dumps(data, indent=2, sort_keys=True))
    else:
        print(render_text(data))
        if args.task_id and args.summary:
             print(f"Intake logged: {logged}")
             if data.get("duplicate"):
                 print("!! WARNING: Duplicate task detected !!")

    return 0

if __name__ == "__main__":
    sys.exit(main())
