# gmx/commands/plan.py
"""
CLI command for generating a GMX plan from a natural language prompt.
"""
from __future__ import annotations
import json
from pathlib import Path
from agents.gmx_cli.planner import GMXPlanner
from agents.gmx_cli.validator import validate_plan

PLAN_OUTPUT_FILE = Path("g/wo_specs/latest_gmx_plan.json")

def plan(prompt: str):
    """
    Takes a user prompt, generates a GMX plan, validates it, and saves it.
    """
    print("--- GMX: Planning Mode ---")
    planner = GMXPlanner()
    gmx_json = planner.create_plan_from_prompt(prompt)

    if gmx_json.get("status") == "ERROR":
        print(f"FATAL ERROR during planning: {gmx_json.get('reason')}")
        return

    errors = validate_plan(gmx_json)
    if errors:
        print("FATAL ERROR: Plan failed validation.")
        for error in errors:
            print(f"- {error}")
        return

    PLAN_OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    with PLAN_OUTPUT_FILE.open("w", encoding="utf-8") as f:
        json.dump(gmx_json, f, indent=2)
    
    print(f"\n✅ SUCCESS: GMX plan validated and saved to '{PLAN_OUTPUT_FILE}'")
