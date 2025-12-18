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
    parser.add_argument("--skip-pr-check", action="store_true", help="Skip PR preflight check (Boss override)")
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
        "pr_num": None,
        "pr_zone": None,
        "pr_mergeable": None,
        "pr_blocked": False,
        "errors": None,
        "notes": None,
    }

    # --- PR Preflight Check (Gate) ---
    pr_preflight_blocked = False
    pr_preflight_reason: list[str] = []
    pr_preflight_zone = "unknown"

    if not args.skip_pr_check:
        try:
            # Get currently checked-out branch
            current_branch = subprocess.run(
                ["git", "branch", "--show-current"],
                cwd=REPO_ROOT,
                capture_output=True,
                text=True,
                check=True
            ).stdout.strip()

            if current_branch:
                # Find PR for this branch
                pr_result = subprocess.run(
                    ["gh", "pr", "view", current_branch, "--json", "number,files,mergeable"],
                    cwd=REPO_ROOT,
                    capture_output=True,
                    text=True
                )

                if pr_result.returncode == 0:
                    pr_info = json.loads(pr_result.stdout)
                    pr_num = pr_info.get("number")
                    pr_files = [f["path"] for f in pr_info.get("files", [])]
                    pr_mergeable = pr_info.get("mergeable")

                    # Classify zone (same logic as pr_decision_advisory.zsh)
                    for file_path in pr_files:
                        if "g/docs/GOVERNANCE" in file_path or "g/docs/AI_OP_001" in file_path:
                            pr_preflight_zone = "GOVERNANCE"
                            break
                        elif file_path.startswith("bridge/core") or file_path.startswith("core/"):
                            pr_preflight_zone = "LOCKED_CORE"
                            break

                    if pr_preflight_zone == "unknown":
                        for file_path in pr_files:
                            if file_path.startswith(("g/docs", "g/reports", "g/manuals", "personas")):
                                pr_preflight_zone = "DOCS"
                                break
                            elif file_path.startswith(("tools", "tests", "apps")):
                                pr_preflight_zone = "OPEN"
                                break

                    # GATE: Block if high-risk zone OR conflicts
                    if pr_preflight_zone in ("GOVERNANCE", "LOCKED_CORE"):
                        pr_preflight_blocked = True
                        pr_preflight_reason.append(f"High-risk zone: {pr_preflight_zone}")
                        pr_preflight_reason.append("Requires Boss approval before seal-now")

                    if pr_mergeable == "CONFLICTING":
                        pr_preflight_blocked = True
                        pr_preflight_reason.append("PR has merge conflicts")
                        pr_preflight_reason.append("Resolve conflicts before seal-now")

                    record["pr_num"] = pr_num
                    record["pr_zone"] = pr_preflight_zone
                    record["pr_mergeable"] = pr_mergeable
                    record["pr_blocked"] = pr_preflight_blocked

        except Exception as e:
            # No PR found or error → continue without blocking
            record["notes"] = f"PR preflight skipped: {e}"

    # GATE: If blocked, exit early
    if pr_preflight_blocked:
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🚫 PR PREFLIGHT CHECK BLOCKED")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        for reason in pr_preflight_reason:
            print(f"  ⚠️  {reason}")
        print("")
        print("📋 Run pr-check for full analysis:")
        if record.get("pr_num"):
            print(f"   pr-check {record['pr_num']}")
        print("")
        print("After resolving, re-run:")
        print("   seal-now")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        record["review_exit_code"] = None
        record["gitdrop_status"] = "blocked_by_pr"
        record["save_status"] = "blocked_by_pr"
        record["duration_ms_total"] = int((time.monotonic() - chain_start) * 1000)
        record["errors"] = "; ".join(pr_preflight_reason)
        _append_record(record)
        return 0  # Exit early, don't run review/gitdrop/save

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
