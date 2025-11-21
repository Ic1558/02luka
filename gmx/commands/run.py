# gmx/commands/run.py
"""
CLI command for dispatching a GMX plan to the Bridge.
"""
from __future__ import annotations
import json
import sys
from pathlib import Path

# This assumes the main gmx.py entrypoint has already set up the system path.
from bridge.tools.dispatch_to_bridge import dispatch_work_order

PLAN_FILE = Path("g/wo_specs/latest_gmx_plan.json")

def run():
    """
    Loads the latest GMX plan, extracts the task_spec, and dispatches it
    as a Work Order to the Bridge.
    """
    print("--- GMX: Run Mode (Dispatching) ---")

    if not PLAN_FILE.exists():
        print(f"FATAL ERROR: Plan file not found at '{PLAN_FILE}'. Run 'gmx plan' first.", file=sys.stderr)
        sys.exit(1)

    try:
        with PLAN_FILE.open("r", encoding="utf-8") as f:
            gmx_json = json.load(f)

        task_spec = gmx_json.get("task_spec")
        if not task_spec:
            print("FATAL ERROR: 'task_spec' not found in the plan file.", file=sys.stderr)
            sys.exit(1)

        print(f"Dispatching task_spec with intent: {task_spec.get('intent')}")
        dispatch_work_order(task_spec, source='gmx_run')

    except json.JSONDecodeError as e:
        print(f"FATAL ERROR: Could not parse plan file '{PLAN_FILE}'. Error: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"An unexpected error occurred during dispatch: {e}", file=sys.stderr)
        sys.exit(1)
