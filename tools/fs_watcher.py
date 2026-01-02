#!/usr/bin/env python3
"""Passive filesystem watcher that appends JSONL telemetry."""

import json
import os
import time
try:
    with open("/tmp/fs_watcher_probe.txt", "w") as f:
        f.write(f"Started at {time.time()}\n")
except: pass
import signal
import socket
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Tuple


REPO_ROOT = Path(__file__).resolve().parent.parent
ALLOWED_ROOTS = [
    REPO_ROOT / "tools",
    REPO_ROOT / "infra",
    REPO_ROOT / "g" / "reports",
    REPO_ROOT / "g" / "docs",
]
IGNORE_DIR_NAMES = {
    ".git",
    "node_modules",
    "logs",
    "telemetry",  # Exclude telemetry output directory
}
IGNORE_FILE_EXT = {".log", ".err", ".out"}
IGNORE_EXACT = {
    "g/telemetry/fs_index.jsonl",
}
TELEMETRY_FILE = REPO_ROOT / "g" / "telemetry" / "fs_index.jsonl"
SCAN_INTERVAL_SEC = 2

LANE = "FS_DAEMON"
ACTOR = os.getenv("ACTOR") or os.getenv("AGENT_ID") or os.getenv("GG_AGENT_ID") or "unknown"
HOST = socket.gethostname()
PID = os.getpid()

_running = True


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _git_rev() -> str:
    try:
        out = subprocess.check_output(["git", "-C", str(REPO_ROOT), "rev-parse", "--short", "HEAD"], text=True)
        return out.strip()
    except Exception:
        return "unknown"


GIT_REV = _git_rev()


def should_ignore(path: Path, is_dir: bool) -> bool:
    # Hard ignore for specific output file (Resolution)
    try:
        if path.resolve() == TELEMETRY_FILE.resolve():
            return True
    except OSError:
        pass # Path might not exist yet

    rel = path.relative_to(REPO_ROOT).as_posix()
    if rel in IGNORE_EXACT:
        return True
    parts = path.parts
    if any(part in IGNORE_DIR_NAMES for part in parts):
        return True
    if is_dir:
        return False
    if path.suffix in IGNORE_FILE_EXT:
        return True
    return False


def snapshot() -> Dict[str, Tuple[float, int, str]]:
    state: Dict[str, Tuple[float, int, str]] = {}
    for root in ALLOWED_ROOTS:
        if not root.exists():
            continue
        for dirpath, dirnames, filenames in os.walk(root):
            current_dir = Path(dirpath)
            rel_dir = current_dir.relative_to(REPO_ROOT)
            dirnames[:] = [d for d in dirnames if not should_ignore(current_dir / d, True)]

            # Track directory entries
            if not should_ignore(current_dir, True):
                try:
                    st = current_dir.stat()
                    state[rel_dir.as_posix()] = (st.st_mtime, st.st_size, "dir")
                except FileNotFoundError:
                    pass

            for fname in filenames:
                fpath = current_dir / fname
                if should_ignore(fpath, False):
                    continue
                rel_file = fpath.relative_to(REPO_ROOT)
                try:
                    st = fpath.stat()
                except FileNotFoundError:
                    continue
                state[rel_file.as_posix()] = (st.st_mtime, st.st_size, "file")
    return state


def diff(prev: Dict[str, Tuple[float, int, str]], curr: Dict[str, Tuple[float, int, str]]):
    events = []
    for path, meta in curr.items():
        if path not in prev:
            events.append(("created", path, meta[2]))
        else:
            if meta[0] != prev[path][0] or meta[1] != prev[path][1]:
                events.append(("modified", path, meta[2]))
    for path, meta in prev.items():
        if path not in curr:
            events.append(("deleted", path, meta[2]))
    return events


def append_event(file_path: Path, event: str, rel_path: str, ftype: str):
    record = {
        "ts": _utc_now(),
        "event": event,
        "lane": LANE,
        "actor": ACTOR,
        "file": rel_path,
        "type": ftype,
        "host": HOST,
        "pid": PID,
        "git_rev": GIT_REV,
    }
    file_path.parent.mkdir(parents=True, exist_ok=True)
    with file_path.open("a", encoding="utf-8") as f:
        f.write(json.dumps(record, ensure_ascii=False) + "\n")


def handle_signal(_signum, _frame):
    global _running
    _running = False


def main():
    signal.signal(signal.SIGTERM, handle_signal)
    signal.signal(signal.SIGINT, handle_signal)

    prev = snapshot()  # warm start, no events emitted
    while _running:
        time.sleep(SCAN_INTERVAL_SEC)
        curr = snapshot()
        for ev, path, ftype in diff(prev, curr):
            append_event(TELEMETRY_FILE, ev, path, ftype)
        prev = curr


if __name__ == "__main__":
    main()
