#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Dict, Optional

from tools.lib.workflow_chain_utils import (
    determine_caller,
    generate_run_id,
    iso_now,
    parse_gitdrop_snapshot_id,
)


REPO_ROOT = Path(__file__).resolve().parents[1]
TELEMETRY_FILE = REPO_ROOT / "g" / "telemetry" / "dev_workflow_chain.jsonl"


def _run(cmd: list[str], cwd: Path) -> tuple[int, str, str, int]:
    start = time.monotonic()
    proc = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    duration_ms = int((time.monotonic() - start) * 1000)
    return proc.returncode, proc.stdout, proc.stderr, duration_ms


def _load_review_json(path: Path) -> Dict[str, Any]:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {}


def main(argv: Optional[list[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Unified workflow chain: review → gitdrop → save")
    parser.add_argument("--mode", default="staged", choices=["staged", "unstaged", "last-commit", "branch", "range"])
    parser.add_argument("--base", help="Base ref (for branch/range)")
    parser.add_argument("--target", help="Target ref (for branch/range)")
    parser.add_argument("--offline", action="store_true", help="Run review in offline mode")
    parser.add_argument("--strict", action="store_true", help="Treat warnings as failures in review")
    parser.add_argument("--skip-gitdrop", action="store_true", help="Skip gitdrop step")
    parser.add_argument("--skip-save", action="store_true", help="Skip save step")
    args = parser.parse_args(argv)

    run_id = os.getenv("RUN_ID") or generate_run_id()
    caller = determine_caller()
    ts = iso_now()
    chain_start = time.monotonic()

    record: Dict[str, Any] = {
        "ts": ts,
        "run_id": run_id,
        "caller": caller,
        "mode": args.mode,
        "offline": bool(args.offline),
        "review_exit_code": None,
        "review_report_path": None,
        "review_truncated": None,
        "security_blocked": False,
        "files_included": None,
        "files_excluded": None,
        "gitdrop_snapshot_id": None,
        "gitdrop_status": "skipped",
        "save_status": "skipped",
        "duration_ms_total": None,
        "duration_ms_review": None,
        "duration_ms_gitdrop": None,
        "duration_ms_save": None,
        "errors": None,
        "notes": None,
    }

    # --- Review step ---
    report_dir = REPO_ROOT / "g" / "reports" / "reviews"
    report_dir.mkdir(parents=True, exist_ok=True)
    report_path = report_dir / f"{run_id}.json"
    review_cmd = [
        sys.executable,
        str(REPO_ROOT / "tools" / "local_agent_review.py"),
        args.mode,
        "--format",
        "json",
        "--output",
        str(report_path),
        "--quiet",
    ]
    if args.offline:
        review_cmd.append("--offline")
    if args.strict:
        review_cmd.append("--strict")
    if args.base:
        review_cmd.extend(["--base", args.base])
    if args.target:
        review_cmd.extend(["--target", args.target])

    review_rc, review_out, review_err, dur_review = _run(review_cmd, cwd=REPO_ROOT)
    record["review_exit_code"] = review_rc
    record["duration_ms_review"] = dur_review

    review_data = _load_review_json(report_path) if report_path.exists() else {}
    diff_info = review_data.get("diff", {}) if isinstance(review_data, dict) else {}
    record["review_report_path"] = str(report_path.relative_to(REPO_ROOT)) if report_path.exists() else None
    record["review_truncated"] = bool(diff_info.get("truncated", False))
    record["files_included"] = len(diff_info.get("files_included", []) or [])
    record["files_excluded"] = len(diff_info.get("files_excluded", []) or [])
    record["security_blocked"] = review_rc == 3

    errors: list[str] = []
    if review_rc == 2:
        errors.append("review_exit_code=2 (config/system error)")
    if review_rc not in (0, 1):
        # Skip downstream steps
        record["gitdrop_status"] = "skipped"
        record["save_status"] = "skipped"
        total = int((time.monotonic() - chain_start) * 1000)
        record["duration_ms_total"] = total
        if errors:
            record["errors"] = "; ".join(errors)
        _append_record(record)
        return 0

    if review_rc == 3:
        # Security block
        record["gitdrop_status"] = "skipped"
        record["save_status"] = "skipped"
        total = int((time.monotonic() - chain_start) * 1000)
        record["duration_ms_total"] = total
        record["errors"] = "security block (secrets detected)"
        _append_record(record)
        return 0

    # --- GitDrop step ---
    gitdrop_rc: Optional[int] = None
    gitdrop_duration: Optional[int] = None
    gitdrop_output = ""
    if not args.skip_gitdrop and (REPO_ROOT / "tools" / "gitdrop.py").exists():
        gitdrop_cmd = [
            sys.executable,
            str(REPO_ROOT / "tools" / "gitdrop.py"),
            "backup",
            "--reason",
            f"workflow_dev_review_save:{run_id}",
        ]
        gitdrop_rc, gitdrop_out, gitdrop_err, gitdrop_duration = _run(gitdrop_cmd, cwd=REPO_ROOT)
        gitdrop_output = gitdrop_out + gitdrop_err
        record["duration_ms_gitdrop"] = gitdrop_duration
        snapshot_id = parse_gitdrop_snapshot_id(gitdrop_output or "")
        if gitdrop_rc == 0 and snapshot_id:
            record["gitdrop_status"] = "ok"
            record["gitdrop_snapshot_id"] = snapshot_id
        elif gitdrop_rc == 0 and not snapshot_id:
            record["gitdrop_status"] = "skipped"
        else:
            record["gitdrop_status"] = "fail"
            errors.append(f"gitdrop failed rc={gitdrop_rc}")
            if gitdrop_output:
                errors.append(gitdrop_output.strip().splitlines()[0])
    else:
        record["gitdrop_status"] = "skipped"

    # --- Save step ---
    if not args.skip_save and (REPO_ROOT / "tools" / "session_save.zsh").exists():
        if record["gitdrop_status"] == "fail":
            record["save_status"] = "skipped"
        else:
            env = os.environ.copy()
            env["RUN_ID"] = run_id
            if record.get("gitdrop_snapshot_id"):
                env["GITDROP_SNAPSHOT_ID"] = str(record["gitdrop_snapshot_id"])
            save_cmd = [str(REPO_ROOT / "tools" / "session_save.zsh")]
            save_rc, save_out, save_err, dur_save = _run(save_cmd, cwd=REPO_ROOT)
            record["duration_ms_save"] = dur_save
            if save_rc == 0:
                record["save_status"] = "ok"
            else:
                record["save_status"] = "fail"
                errors.append(f"save failed rc={save_rc}")
                if save_err:
                    errors.append(save_err.strip().splitlines()[0])
    else:
        record["save_status"] = "skipped"

    record["duration_ms_total"] = int((time.monotonic() - chain_start) * 1000)
    if errors:
        record["errors"] = "; ".join(errors)
    _append_record(record)
    return 0


def _append_record(record: Dict[str, Any]) -> None:
    TELEMETRY_FILE.parent.mkdir(parents=True, exist_ok=True)
    with TELEMETRY_FILE.open("a", encoding="utf-8") as f:
        f.write(json.dumps(record) + "\n")


if __name__ == "__main__":
    sys.exit(main())
