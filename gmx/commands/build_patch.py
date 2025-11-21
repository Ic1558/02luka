# gmx/commands/build_patch.py
"""
CLI command for building a unified patch from a GMX plan.
"""
from __future__ import annotations
import json
from pathlib import Path
from agents.gmx_cli.patcher import create_patch_from_plan

PLAN_FILE = Path("g/wo_specs/latest_gmx_plan.json")

def build_patch():
    """
    Loads the latest GMX plan, generates a patch, and prints it.
    """
    print("--- GMX: Building Patch ---")
    if not PLAN_FILE.exists():
        print(f"ERROR: Plan file not found at '{PLAN_FILE}'. Run 'gmx plan' first.")
        return

    with PLAN_FILE.open("r", encoding="utf-8") as f:
        plan = json.load(f)

    patch_str = create_patch_from_plan(plan)
    print("\n--- Generated Unified Patch ---")
    print(patch_str)
