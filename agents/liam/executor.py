from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
from typing import Any, Dict, List

from tools.ap_io_v31.writer import write_ledger_entry


PROJECT_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SPEC_PATH = PROJECT_ROOT / "g" / "wo_specs" / "gmx_liam_selftest.json"
BRIDGE_INBOX_ROOT = PROJECT_ROOT / "bridge" / "inbox"


class LiamExecutorError(Exception):
    """Custom exception for Liam executor failures."""


def load_spec(path: Path) -> Dict[str, Any]:
    if not path.exists():
        raise LiamExecutorError(f"Spec file not found: {path}")
    try:
        with path.open("r", encoding="utf-8") as f:
            return json.load(f)
    except json.JSONDecodeError as e:
        raise LiamExecutorError(f"Invalid JSON in spec file {path}: {e}") from e


def ensure_under(base: Path, target: Path) -> None:
    """Ensure target is within base (security guardrail)."""
    try:
        target.relative_to(base)
    except ValueError as e:
        raise LiamExecutorError(
            f"Refusing to write outside inbox root. Base={base}, target={target}"
        ) from e


def handle_write_ledger_entry(details: Dict[str, Any], dry_run: bool) -> str:
    agent = details.get("agent", "Liam")
    event = details.get("event", "unknown_event")
    data = details.get("data", {}) or {}
    parent_id = details.get("parent_id")
    correlation_id = details.get("correlation_id")
    execution_duration_ms = details.get("execution_duration_ms")

    if dry_run:
        print(
            f"[DRY-RUN] write_ledger_entry("
            f"agent={agent!r}, event={event!r}, parent_id={parent_id!r}, "
            f"correlation_id={correlation_id!r}, execution_duration_ms={execution_duration_ms!r}, "
            f"data={data!r})"
        )
        return "dry-run-ledger-id"

    ledger_id = write_ledger_entry(
        agent=agent,
        event=event,
        data=data,
        parent_id=parent_id,
        correlation_id=correlation_id,
        execution_duration_ms=execution_duration_ms,
    )
    print(f"[LEDGER] wrote entry id={ledger_id} event={event} agent={agent}")
    return ledger_id


def handle_write_to_bridge(details: Dict[str, Any], dry_run: bool) -> Path:
    inbox_name = details.get("inbox")
    filename = details.get("filename")
    content = details.get("content", {})

    if not inbox_name or not filename:
        raise LiamExecutorError(
            f"write_to_bridge requires 'inbox' and 'filename', got: {details}"
        )

    target_dir = BRIDGE_INBOX_ROOT / inbox_name
    target_path = target_dir / filename

    ensure_under(BRIDGE_INBOX_ROOT, target_path)

    if dry_run:
        print(
            f"[DRY-RUN] write_to_bridge(inbox={inbox_name!r}, "
            f"filename={filename!r}) -> {target_path}"
        )
        print(f"[DRY-RUN] content: {json.dumps(content, indent=2, ensure_ascii=False)}")
        return target_path

    target_dir.mkdir(parents=True, exist_ok=True)
    with target_path.open("w", encoding="utf-8") as f:
        json.dump(content, f, ensure_ascii=False, indent=2)

    print(f"[BRIDGE] wrote WO file to {target_path}")
    return target_path


def execute_steps(steps: List[Dict[str, Any]], dry_run: bool = False) -> None:
    # Ensure we run from PROJECT_ROOT so writer.py paths are correct
    os.chdir(PROJECT_ROOT)

    # Sort by "step" to be deterministic
    ordered_steps = sorted(steps, key=lambda s: s.get("step", 0))

    for step in ordered_steps:
        step_no = step.get("step")
        action = step.get("action")
        details = step.get("details", {}) or {}

        print(f"\n[STEP {step_no}] action={action}")

        if action == "write_ledger_entry":
            handle_write_ledger_entry(details, dry_run=dry_run)

        elif action == "write_to_bridge":
            handle_write_to_bridge(details, dry_run=dry_run)

        else:
            raise LiamExecutorError(f"Unknown action in step {step_no}: {action!r}")


def get_steps(spec: Dict[str, Any]) -> List[Dict[str, Any]]:
    """
    Retrieve steps from the spec, supporting multiple locations.
    Priority:
    1. gmx_plan.steps
    2. task_spec.context.steps
    """
    # 1. Try gmx_plan.steps
    gmx_plan = spec.get("gmx_plan", {})
    if gmx_plan and "steps" in gmx_plan:
        return gmx_plan["steps"]

    # 2. Try task_spec.context.steps
    task_spec = spec.get("task_spec", {})
    context = task_spec.get("context", {})
    if context and "steps" in context:
        return context["steps"]

    raise LiamExecutorError(
        "No steps found in 'gmx_plan.steps' or 'task_spec.context.steps'"
    )


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Liam Executor - Run GMX-generated AP/IO v3.1 workflows."
    )
    parser.add_argument(
        "spec_path",
        nargs="?",
        default=str(DEFAULT_SPEC_PATH),
        help="Path to GMX spec JSON (default: g/wo_specs/gmx_liam_selftest.json)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Simulate actions without writing ledger or bridge files.",
    )

    args = parser.parse_args()
    spec_path = Path(args.spec_path).expanduser().resolve()
    dry_run = args.dry_run

    try:
        spec = load_spec(spec_path)
        steps = get_steps(spec)

        print(f"[LIAM-EXECUTOR] Spec: {spec_path}")
        print(f"[LIAM-EXECUTOR] Steps: {len(steps)} (dry_run={dry_run})")

        execute_steps(steps, dry_run=dry_run)

        print("\n[LIAM-EXECUTOR] Completed all steps successfully.")

    except LiamExecutorError as e:
        print(f"[LIAM-EXECUTOR][ERROR] {e}")
        raise SystemExit(1)
    except Exception as e:
        print(f"[LIAM-EXECUTOR][FATAL] Unexpected error: {e}")
        raise SystemExit(1)


if __name__ == "__main__":
    main()
