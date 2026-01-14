#!/usr/bin/env python3
"""MLS symlink guardrail: auto-heal g/knowledge/mls_*.json* if not symlink."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import time
from datetime import datetime
from pathlib import Path
from typing import Optional, Tuple

REPO_DEFAULT = Path(os.environ.get("LUKA_ROOT") or os.environ.get("LUKA_SOT") or os.path.expanduser("~/02luka")).resolve()
WS_DEFAULT = Path(os.environ.get("LUKA_WS_ROOT") or os.path.expanduser("~/02luka_ws")).resolve()

WATCH_GLOB = "mls_*.json*"

PRIMARY_FILES = {
    "mls_index.json",
    "mls_lessons.jsonl",
}


def now_ts() -> str:
    return datetime.now().astimezone().isoformat()


def safe_timestamp() -> str:
    return datetime.now().strftime("%Y%m%d-%H%M%S")


def expected_target(ws_root: Path, name: str) -> Path:
    return ws_root / "g" / "knowledge" / name


def find_writer(path: Path) -> Tuple[Optional[int], Optional[str]]:
    lsof = shutil.which("lsof")
    if not lsof:
        return None, None
    try:
        output = subprocess.check_output(
            [lsof, "-n", "-P", "-Fpc", "--", str(path)],
            stderr=subprocess.DEVNULL,
            text=True,
        )
    except Exception:
        return None, None
    pid = None
    proc = None
    for line in output.splitlines():
        if line.startswith("p") and pid is None:
            try:
                pid = int(line[1:])
            except ValueError:
                pid = None
        elif line.startswith("c") and proc is None:
            proc = line[1:]
        if pid is not None and proc is not None:
            break
    return pid, proc


def severity_for(proc: Optional[str]) -> str:
    if not proc:
        return "high"
    lower = proc.lower()
    if "electron" in lower or lower.startswith("language_server"):
        return "low"
    if lower.startswith("git"):
        return "info"
    if lower in {"bash", "zsh", "sh", "python", "python3"} or "python" in lower:
        return "high"
    return "warning"


def log_event(log_path: Path, payload: dict) -> None:
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with log_path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(payload, ensure_ascii=True) + "\n")


def move_to_recovered(src: Path, recovered_dir: Path) -> Tuple[Path | bool, bool]:
    if not src.exists() or src.is_symlink():
        return False, False
    recovered_dir.mkdir(parents=True, exist_ok=True)
    suffix = safe_timestamp()
    recovered_name = f"{src.name}.regular.{suffix}"
    recovered_path = recovered_dir / recovered_name
    temp_path = recovered_dir / f".{recovered_name}.tmp"
    try:
        if temp_path.exists():
            temp_path.unlink()
        shutil.copy2(src, temp_path)
        os.replace(temp_path, recovered_path)  # recovered copy is now durable

        # Best-effort delete of source. If this fails, we still succeeded at recovery.
        try:
            src.unlink()
            return recovered_path, True
        except Exception:
            # Keep recovered copy; caller may still recreate symlink (which can remove src).
            return recovered_path, False

    except Exception:
        try:
            if temp_path.exists():
                temp_path.unlink()
        except Exception:
            pass
        return False, False


def ensure_symlink(link_path: Path, target: Path) -> bool:
    try:
        if link_path.exists() or link_path.is_symlink():
            link_path.unlink()
        link_path.symlink_to(target)
        return True
    except Exception:
        return False


def verify_symlink(link_path: Path, target: Path) -> bool:
    if not link_path.is_symlink():
        return False
    try:
        raw = os.readlink(link_path)
        if os.path.isabs(raw):
            resolved = Path(raw).resolve()
        else:
            resolved = (link_path.parent / raw).resolve()
        return resolved == target.resolve()
    except Exception:
        return False


def cleanup_backups(watch_dir: Path, recovered_dir: Path) -> int:
    count = 0
    for path in watch_dir.glob("mls_*.json*.bak*"):
        if path.is_symlink() or not path.exists():
            continue
        rec_path, _ = move_to_recovered(path, recovered_dir)
        if rec_path:
            count += 1
    return count


def handle_violation(
    file_path: Path,
    ws_root: Path,
    repo_root: Path,
    log_path: Path,
    recovered_dir: Path,
) -> None:
    pid, proc = find_writer(file_path)
    severity = severity_for(proc)
    action = "auto_heal"

    recovered_path, src_removed = move_to_recovered(file_path, recovered_dir)
    if recovered_path is False:
        try:
            rel_path = str(file_path.relative_to(repo_root))
        except ValueError:
            rel_path = str(file_path)
        log_event(
            log_path,
            {
                "ts": now_ts(),
                "file": rel_path,
                "pid": pid,
                "process": proc,
                "action": "recover_failed",
                "severity": "error",
            },
        )
        return

    should_recreate = file_path.name in PRIMARY_FILES
    if not should_recreate and ".bak" in file_path.name:
        should_recreate = False

    symlink_ok = None
    if should_recreate:
        target = expected_target(ws_root, file_path.name)
        ensure_symlink(file_path, target)
        symlink_ok = verify_symlink(file_path, target)

    if proc and proc.lower().startswith("git") and ".bak" in file_path.name:
        cleanup_backups(file_path.parent, recovered_dir)

    try:
        rel_path = str(file_path.relative_to(repo_root))
    except ValueError:
        rel_path = str(file_path)

    payload = {
        "ts": now_ts(),
        "file": rel_path,
        "pid": pid,
        "process": proc,
        "action": action,
        "severity": severity,
        "src_removed": src_removed,
    }
    if recovered_path:
        payload["recovered_path"] = str(recovered_path)
    if symlink_ok is not None:
        payload["symlink_ok"] = symlink_ok
    log_event(log_path, payload)


def scan_once(repo_root: Path, ws_root: Path, log_path: Path) -> None:
    watch_dir = repo_root / "g" / "knowledge"
    recovered_dir = ws_root / "g" / "knowledge" / "recovered"

    if not watch_dir.exists():
        return

    for file_path in sorted(watch_dir.glob(WATCH_GLOB)):
        if not file_path.exists() and not file_path.is_symlink():
            continue

        expected = expected_target(ws_root, file_path.name)
        if file_path.is_symlink():
            if file_path.name in PRIMARY_FILES:
                if not verify_symlink(file_path, expected):
                    handle_violation(file_path, ws_root, repo_root, log_path, recovered_dir)
            continue

        handle_violation(file_path, ws_root, repo_root, log_path, recovered_dir)


def main() -> int:
    parser = argparse.ArgumentParser(description="Guard MLS symlinks in g/knowledge")
    parser.add_argument("--interval", type=int, default=5, help="Seconds between scans (default: 5)")
    parser.add_argument("--once", action="store_true", help="Run a single scan and exit")
    parser.add_argument("--repo", default=str(REPO_DEFAULT), help="Repo root (default: ~/02luka)")
    parser.add_argument("--ws", default=str(WS_DEFAULT), help="Workspace root (default: ~/02luka_ws)")
    parser.add_argument(
        "--log",
        default=str(WS_DEFAULT / "g" / "telemetry" / "mls_symlink_violations.jsonl"),
        help="Log path (default: ~/02luka_ws/g/telemetry/mls_symlink_violations.jsonl)",
    )
    args = parser.parse_args()

    repo_root = Path(args.repo).expanduser().resolve()
    ws_root = Path(args.ws).expanduser().resolve()
    log_path = Path(args.log).expanduser().resolve()

    if args.once:
        scan_once(repo_root, ws_root, log_path)
        return 0

    interval = max(5, min(args.interval, 600))
    while True:
        scan_once(repo_root, ws_root, log_path)
        time.sleep(interval)


if __name__ == "__main__":
    raise SystemExit(main())
