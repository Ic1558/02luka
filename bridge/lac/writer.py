#!/usr/bin/env python3
"""Best-effort LAC state writer (non-blocking)."""

from __future__ import annotations

import json
import os
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Optional


STATE_PATH = Path(__file__).resolve().parent / "lac_state.yaml"
VALID_STATUSES = {"completed", "running", "error"}
WORK_NOTES_MAX = 200


def _parse_scalar(value: str) -> Any:
    if value in ("null", "~"):
        return None
    if value.startswith('"') and value.endswith('"'):
        try:
            return json.loads(value)
        except json.JSONDecodeError:
            return value.strip('"')
    if value.startswith("'") and value.endswith("'"):
        return value.strip("'")
    return value


def _parse_state(text: str) -> Dict[str, Any]:
    stripped = text.lstrip()
    if stripped.startswith("{"):
        try:
            return json.loads(text)
        except json.JSONDecodeError:
            return {}

    data: Dict[str, Any] = {"version": None, "updated_at": None, "lanes": {}}
    in_lanes = False
    current_lane: Optional[str] = None
    for raw in text.splitlines():
        line = raw.split("#", 1)[0].rstrip()
        if not line.strip():
            continue
        if line.startswith("version:"):
            data["version"] = _parse_scalar(line.split(":", 1)[1].strip())
            continue
        if line.startswith("updated_at:"):
            data["updated_at"] = _parse_scalar(line.split(":", 1)[1].strip())
            continue
        if line.startswith("lanes:"):
            in_lanes = True
            tail = line.split(":", 1)[1].strip()
            if tail == "{}":
                data["lanes"] = {}
                in_lanes = False
            continue
        if in_lanes and line.startswith("  ") and not line.startswith("    "):
            lane = line.strip()
            if lane.endswith(":"):
                lane = lane[:-1].strip()
            current_lane = lane or None
            if current_lane:
                data["lanes"].setdefault(current_lane, {})
            continue
        if in_lanes and line.startswith("    ") and current_lane:
            key, _, raw_value = line.strip().partition(":")
            data["lanes"][current_lane][key.strip()] = _parse_scalar(raw_value.strip())
    return data


def _empty_state() -> Dict[str, Any]:
    return {"version": "1.0", "updated_at": "1970-01-01T00:00:00Z", "lanes": {}}


def _normalize_state(state: Dict[str, Any]) -> Dict[str, Any]:
    if not isinstance(state, dict):
        return _empty_state()
    state.setdefault("version", "1.0")
    state.setdefault("updated_at", "1970-01-01T00:00:00Z")
    lanes = state.get("lanes")
    if not isinstance(lanes, dict):
        state["lanes"] = {}
    return state


def _dump_state(state: Dict[str, Any]) -> str:
    lanes = state.get("lanes") if isinstance(state, dict) else {}
    if not isinstance(lanes, dict):
        lanes = {}
    lines = [
        f'version: "{state.get("version", "1.0")}"',
        f'updated_at: "{state.get("updated_at", "1970-01-01T00:00:00Z")}"',
    ]
    if not lanes:
        lines.append("lanes: {}")
        return "\n".join(lines) + "\n"
    lines.append("lanes:")
    for lane in sorted(lanes.keys()):
        info = lanes[lane] if isinstance(lanes[lane], dict) else {}
        lines.append(f"  {lane}:")
        for key in ["owner", "last_task", "status", "last_output", "last_ts"]:
            value = info.get(key)
            if value is None:
                lines.append(f"    {key}: null")
            else:
                lines.append(f"    {key}: {json.dumps(value)}")
    return "\n".join(lines) + "\n"


def _write_state_atomic(path: Path, state: Dict[str, Any]) -> None:
    temp_path = path.with_suffix(path.suffix + ".tmp")
    payload = _dump_state(state)
    temp_path.write_text(payload, encoding="utf-8")
    os.replace(temp_path, path)


class LACWriter:
    def __init__(self, path: Optional[Path] = None):
        self.path = path or STATE_PATH

    def update_lane(
        self,
        lane: str,
        task_id: str,
        status: str,
        output_path: Optional[str] = None,
    ) -> bool:
        if not lane or not task_id or status not in VALID_STATUSES:
            return False
        try:
            import fcntl
        except Exception:
            return False

        try:
            self.path.parent.mkdir(parents=True, exist_ok=True)
            with self.path.open("a+", encoding="utf-8") as handle:
                try:
                    fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
                except OSError:
                    return False
                handle.seek(0)
                raw = handle.read()
                state = _normalize_state(_parse_state(raw) if raw else _empty_state())
                lanes = state.setdefault("lanes", {})
                lane_state = lanes.get(lane, {}) if isinstance(lanes, dict) else {}
                owner = lane_state.get("owner") if isinstance(lane_state, dict) else None
                owner = owner or os.environ.get("LAC_AGENT_ID") or os.environ.get("USER") or "unknown"
                now_ts = datetime.now(timezone.utc).isoformat()
                if not isinstance(lanes, dict):
                    lanes = {}
                    state["lanes"] = lanes
                lanes[lane] = {
                    "owner": owner,
                    "last_task": str(task_id),
                    "status": status,
                    "last_output": output_path,
                    "last_ts": now_ts,
                }
                state["updated_at"] = now_ts
                _write_state_atomic(self.path, state)
                return True
        except Exception:
            return False


def _trigger_digest_update_async(journal_path: Path) -> None:
    """
    Phase 4: Async digest update trigger (best-effort, non-blocking).
    Spawns background process to update digest after journal write.
    Failures are silently ignored to not break journal writes.
    """
    try:
        repo_root = journal_path.parents[2]  # g/core_state/work_notes.jsonl -> repo root
        digest_tool = repo_root / "g" / "tools" / "update_work_notes_digest.py"

        if not digest_tool.exists():
            return  # Tool not found, skip silently

        # Spawn async subprocess (fire-and-forget)
        subprocess.Popen(
            ["python3", str(digest_tool), "--lines", "200", "--incremental"],
            cwd=str(repo_root),
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,  # Detach from parent
        )
    except Exception:
        pass  # Silently ignore all errors (hook must not break writes)


def _work_notes_path() -> Path:
    ws_root = os.environ.get("LUKA_WS_ROOT")
    if ws_root:
        return Path(ws_root).expanduser().resolve() / "g" / "core_state" / "work_notes.jsonl"
    repo_root = Path(os.environ.get("LUKA_ROOT", Path(__file__).resolve().parents[2])).resolve()
    return repo_root / "g" / "core_state" / "work_notes.jsonl"


def write_work_note(
    lane: str,
    task_id: str,
    short_summary: str,
    status: str,
    artifact_path: Optional[str] = None,
    timestamp: Optional[str] = None,
) -> bool:
    if not lane or not task_id or not short_summary or not status:
        return False
    path = _work_notes_path()
    try:
        import fcntl
    except Exception:
        return False
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        # Use simple append mode
        with path.open("a", encoding="utf-8") as handle:
            try:
                fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except OSError:
                return False  # Failed to acquire lock
            
            ts = timestamp or datetime.now(timezone.utc).isoformat()
            note = {
                "lane": lane,
                "task_id": task_id,
                "short_summary": short_summary,
                "status": status,
                "artifact_path": artifact_path,
                "timestamp": ts,
            }
            
            # Atomic append line
            handle.write(json.dumps(note) + "\n")
            handle.flush()

            # Phase 4: Async digest update hook (best-effort, non-blocking)
            _trigger_digest_update_async(path)

            return True
    except Exception:
        return False


__all__ = ["LACWriter", "write_work_note"]
