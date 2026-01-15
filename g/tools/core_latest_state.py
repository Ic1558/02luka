#!/usr/bin/env python3
"""Generate a canonical core state snapshot (read-only unless --write)."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
from collections import deque
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional


PROCESS_SPECS = [
    {"key": "mary.py", "patterns": ["mary.py"]},
    {"key": "gateway_router", "patterns": ["gateway_router", "gateway_v3_router", "agent_router.py"]},
    {"key": "lac_manager", "patterns": ["lac_manager.py", "lac_manager"]},
    {"key": "gemini_bridge", "patterns": ["gemini_bridge.py", "gemini_bridge"]},
    {"key": "opal_api", "patterns": ["opal_api", "opal-api", "opal_api.py"]},
]

TELEMETRY_FILES = [
    "g/telemetry/lac_metrics.jsonl",
    "g/telemetry/lac_events.jsonl",
]

MLSSYMLINK_VIOLATIONS = "g/telemetry/mls_symlink_violations.jsonl"

LAC_QUEUE_PATHS = [
    ("bridge/inbox/LAC", "lac_inbox"),
    ("bridge/inbox/lac", "lac_inbox_lower"),
    ("bridge/processing/LAC", "lac_processing"),
    ("bridge/processing/lac", "lac_processing_lower"),
    ("bridge/processed/LAC", "lac_processed"),
    ("bridge/processed/lac", "lac_processed_lower"),
]


def now_local() -> datetime:
    return datetime.now().astimezone()


def now_utc() -> datetime:
    return datetime.now(timezone.utc)


def run_cmd(cmd: List[str], timeout_s: float = 1.0) -> Dict[str, Any]:
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout_s,
            check=False,
        )
        return {
            "ok": result.returncode == 0,
            "code": result.returncode,
            "out": result.stdout.strip(),
            "err": result.stderr.strip(),
        }
    except Exception as exc:
        return {"ok": False, "code": None, "out": "", "err": str(exc)}


def git_root() -> Optional[str]:
    result = run_cmd(["git", "rev-parse", "--show-toplevel"])
    return result["out"] if result["ok"] and result["out"] else None


def git_branch() -> Optional[str]:
    result = run_cmd(["git", "rev-parse", "--abbrev-ref", "HEAD"])
    return result["out"] if result["ok"] and result["out"] else None


def git_head() -> Optional[str]:
    result = run_cmd(["git", "rev-parse", "HEAD"])
    return result["out"] if result["ok"] and result["out"] else None


def git_status_summary(max_files: int = 10) -> Dict[str, Any]:
    result = run_cmd(["git", "status", "--porcelain"])
    lines = result["out"].splitlines() if result["out"] else []
    modified: List[Dict[str, str]] = []
    for line in lines[:max_files]:
        status = line[:2].strip()
        path = line[3:].strip() if len(line) > 3 else line[2:].strip()
        modified.append({"status": status, "path": path})
    return {
        "clean": len(lines) == 0,
        "dirty": len(lines) > 0,
        "modified_count": len(lines),
        "top_modified": modified,
    }


def parse_ps() -> List[Dict[str, str]]:
    result = run_cmd(["ps", "-A", "-o", "pid=,command="], timeout_s=1.0)
    entries = []
    if not result["ok"]:
        return entries
    for line in result["out"].splitlines():
        raw = line.strip()
        if not raw:
            continue
        parts = raw.split(maxsplit=1)
        if len(parts) != 2:
            continue
        entries.append({"pid": parts[0], "cmd": parts[1], "cmd_lower": parts[1].lower()})
    return entries


def find_processes() -> Dict[str, Dict[str, Optional[str]]]:
    entries = parse_ps()
    results: Dict[str, Dict[str, Optional[str]]] = {}
    for spec in PROCESS_SPECS:
        key = spec["key"]
        patterns = [p.lower() for p in spec["patterns"]]
        found = None
        for entry in entries:
            if any(pat in entry["cmd_lower"] for pat in patterns):
                found = entry
                break
        if found:
            results[key] = {"pid": found["pid"], "cmdline": found["cmd"]}
        else:
            results[key] = {"pid": None, "cmdline": None}
    return results


def launchctl_status() -> Dict[str, Any]:
    uid = os.getuid()
    domain = f"gui/{uid}/com.02luka.mls-symlink-guard"
    result = run_cmd(["launchctl", "print", domain], timeout_s=1.2)
    status = {"domain": domain, "running": None, "pid": None, "error": None}
    if not result["ok"]:
        status["error"] = result["err"] or result["out"] or "launchctl print failed"
        return status
    for line in result["out"].splitlines():
        stripped = line.strip()
        if stripped.startswith("state ="):
            state = stripped.split("=", 1)[1].strip()
            status["running"] = state == "running"
        if stripped.startswith("pid ="):
            status["pid"] = stripped.split("=", 1)[1].strip()
    return status


def tail_lines(path: Path, count: int) -> Dict[str, Any]:
    data = {"path": str(path), "exists": path.exists(), "lines": []}
    if not path.exists():
        return data
    try:
        buffer: deque[str] = deque(maxlen=count)
        with path.open("r", encoding="utf-8", errors="replace") as handle:
            for line in handle:
                buffer.append(line.rstrip("\n"))
        data["lines"] = list(buffer)
    except Exception as exc:
        data["error"] = str(exc)
    return data


def count_dir_entries(path: Path) -> Dict[str, Any]:
    if not path.exists():
        return {"path": str(path), "exists": False, "file_count": 0}
    if not path.is_dir():
        return {"path": str(path), "exists": True, "file_count": 0, "error": "not a directory"}
    file_count = 0
    try:
        for entry in path.iterdir():
            if entry.is_file():
                file_count += 1
    except Exception as exc:
        return {"path": str(path), "exists": True, "file_count": file_count, "error": str(exc)}
    return {"path": str(path), "exists": True, "file_count": file_count}


def build_snapshot(repo_root: Path) -> Dict[str, Any]:
    local_time = now_local()
    utc_time = now_utc()

    snapshot: Dict[str, Any] = {
        "timestamp": {
            "local": local_time.isoformat(),
            "utc": utc_time.isoformat(),
        },
        "repo": {
            "root": str(repo_root),
            "branch": git_branch(),
            "head": git_head(),
        },
        "git_status": git_status_summary(),
        "processes": find_processes(),
        "mls_symlink_guard": launchctl_status(),
        "lac_queues": {},
        "telemetry": {
            "lac_metrics_tail": [],
            "mls_symlink_violations_tail": {},
        },
    }

    queue_data = {}
    for rel_path, key in LAC_QUEUE_PATHS:
        queue_data[key] = count_dir_entries(repo_root / rel_path)
    snapshot["lac_queues"] = queue_data

    telemetry_entries = []
    for rel_path in TELEMETRY_FILES:
        telemetry_entries.append(tail_lines(repo_root / rel_path, 20))
    snapshot["telemetry"]["lac_metrics_tail"] = telemetry_entries
    snapshot["telemetry"]["mls_symlink_violations_tail"] = tail_lines(repo_root / MLSSYMLINK_VIOLATIONS, 5)
    return snapshot


def render_markdown(snapshot: Dict[str, Any]) -> str:
    lines: List[str] = []
    ts = snapshot["timestamp"]
    lines.append("# Core Latest State")
    lines.append(f"- Local: {ts.get('local')}")
    lines.append(f"- UTC: {ts.get('utc')}")
    lines.append("")
    repo = snapshot["repo"]
    lines.append("## Repo")
    lines.append(f"- Root: {repo.get('root')}")
    lines.append(f"- Branch: {repo.get('branch')}")
    lines.append(f"- HEAD: {repo.get('head')}")
    git_status = snapshot["git_status"]
    lines.append(f"- Clean: {git_status.get('clean')}")
    lines.append(f"- Modified count: {git_status.get('modified_count')}")
    if git_status.get("top_modified"):
        lines.append("- Top modified:")
        for entry in git_status["top_modified"]:
            lines.append(f"  - {entry.get('status')} {entry.get('path')}")
    lines.append("")

    lines.append("## Processes")
    for key, proc in snapshot["processes"].items():
        pid = proc.get("pid")
        cmd = proc.get("cmdline")
        lines.append(f"- {key}: pid={pid} cmd={cmd}")
    lines.append("")

    guard = snapshot["mls_symlink_guard"]
    lines.append("## MLS Symlink Guard")
    lines.append(f"- Domain: {guard.get('domain')}")
    lines.append(f"- Running: {guard.get('running')}")
    lines.append(f"- PID: {guard.get('pid')}")
    if guard.get("error"):
        lines.append(f"- Error: {guard.get('error')}")
    lines.append("")

    lines.append("## LAC Queues")
    for key, info in snapshot["lac_queues"].items():
        lines.append(f"- {key}: {info.get('file_count')} files (exists={info.get('exists')})")
    lines.append("")

    lines.append("## Telemetry Tails")
    for entry in snapshot["telemetry"]["lac_metrics_tail"]:
        lines.append(f"- {entry.get('path')} (exists={entry.get('exists')}):")
        lines.append("```")
        for line in entry.get("lines", []):
            lines.append(line)
        lines.append("```")
    mls_tail = snapshot["telemetry"]["mls_symlink_violations_tail"]
    lines.append(f"- {mls_tail.get('path')} (exists={mls_tail.get('exists')}):")
    lines.append("```")
    for line in mls_tail.get("lines", []):
        lines.append(line)
    lines.append("```")
    lines.append("")
    return "\\n".join(lines)


def write_outputs(repo_root: Path, snapshot: Dict[str, Any], markdown: str) -> None:
    out_dir = repo_root / "g" / "core_state"
    out_dir.mkdir(parents=True, exist_ok=True)
    json_path = out_dir / "latest.json"
    md_path = out_dir / "latest.md"
    json_path.write_text(json.dumps(snapshot, sort_keys=True, indent=2) + "\\n", encoding="utf-8")
    md_path.write_text(markdown + "\\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate core latest state snapshot.")
    parser.add_argument("--write", action="store_true", help="Write outputs to g/core_state/")
    parser.add_argument("--dry-run", action="store_true", help="Do not write; print JSON + MD")
    args = parser.parse_args()

    root = git_root()
    repo_root = Path(root) if root else Path.cwd()

    snapshot = build_snapshot(repo_root)
    markdown = render_markdown(snapshot)

    if args.write:
        write_outputs(repo_root, snapshot, markdown)

    if args.dry_run:
        print(json.dumps(snapshot, sort_keys=True, indent=2))
        print("\\n---\\n")
        print(markdown)
        return 0

    print(json.dumps(snapshot, sort_keys=True, indent=2))
    return 0


if __name__ == "__main__":
    if sys.version_info >= (3, 7):
        try:
            sys.exit(main())
        except KeyboardInterrupt:
            sys.exit(130)
    else:
        sys.exit(main())
