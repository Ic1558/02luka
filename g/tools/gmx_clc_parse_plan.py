#!/usr/bin/env python3
"""
GMX Plan Parser v1 - Dry-run only
WO: WO-GMX-PARSE-PLAN-SPEC-V1
Created: 2025-11-27

Parses GMX orchestrator plan output and generates candidate WOs.
v1 is dry-run only - NEVER writes to bridge/inbox/CLC/
"""

import argparse
import json
import logging
import sys
from datetime import datetime
from pathlib import Path
from typing import Any, Optional

# ═══════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════
PROJECT_ROOT = Path("/Users/icmini/02luka")
LOG_PATH = PROJECT_ROOT / "logs" / "gmx_clc_parse_plan.log"

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s",
    handlers=[
        logging.FileHandler(LOG_PATH),
        logging.StreamHandler(sys.stderr),
    ],
)
logger = logging.getLogger(__name__)

# ═══════════════════════════════════════════
# Schema Definition
# ═══════════════════════════════════════════
"""
Expected GMX Plan Schema v1:

{
  "timestamp": "2025-11-27T20:00:00Z",
  "source": "gmx_clc_orchestrator",
  "context_summary": "...",
  "items": [
    {
      "type": "clc_task" | "health_fix" | "telemetry" | "noop",
      "priority": "low" | "medium" | "high",
      "target": "opal_api" | "clc_worker" | "mary_bridge" | ...,
      "action": "create_wo" | "log" | "noop",
      "wo_suggestion": {
        "wo_id_hint": "WO-AUTO-FIX-API",
        "title": "Fix OPAL API health check",
        "summary": "...",
        "tasks": [
          "Step 1: ...",
          "Step 2: ..."
        ]
      }
    }
  ]
}
"""

VALID_TYPES = {"clc_task", "health_fix", "telemetry", "noop", "info"}
VALID_PRIORITIES = {"low", "medium", "high"}
VALID_ACTIONS = {"create_wo", "log", "noop", "alert"}


# ═══════════════════════════════════════════
# Validation
# ═══════════════════════════════════════════
def validate_plan(plan: dict) -> tuple[bool, list[str]]:
    """Validate GMX plan against schema. Returns (is_valid, errors)."""
    errors = []
    
    # Required top-level fields
    if "timestamp" not in plan:
        errors.append("Missing required field: timestamp")
    if "items" not in plan:
        errors.append("Missing required field: items")
    elif not isinstance(plan["items"], list):
        errors.append("Field 'items' must be a list")
    
    # Validate each item
    for i, item in enumerate(plan.get("items", [])):
        prefix = f"items[{i}]"
        
        if not isinstance(item, dict):
            errors.append(f"{prefix}: must be an object")
            continue
        
        # Check type
        item_type = item.get("type")
        if item_type not in VALID_TYPES:
            errors.append(f"{prefix}.type: invalid value '{item_type}', expected one of {VALID_TYPES}")
        
        # Check priority
        priority = item.get("priority")
        if priority and priority not in VALID_PRIORITIES:
            errors.append(f"{prefix}.priority: invalid value '{priority}', expected one of {VALID_PRIORITIES}")
        
        # Check action
        action = item.get("action")
        if action and action not in VALID_ACTIONS:
            errors.append(f"{prefix}.action: invalid value '{action}', expected one of {VALID_ACTIONS}")
        
        # If action is create_wo, wo_suggestion is required
        if action == "create_wo":
            wo_sug = item.get("wo_suggestion")
            if not wo_sug:
                errors.append(f"{prefix}: action='create_wo' requires wo_suggestion")
            elif not isinstance(wo_sug, dict):
                errors.append(f"{prefix}.wo_suggestion: must be an object")
            else:
                if not wo_sug.get("title"):
                    errors.append(f"{prefix}.wo_suggestion: missing required field 'title'")
    
    return len(errors) == 0, errors


# ═══════════════════════════════════════════
# Parser
# ═══════════════════════════════════════════
def generate_wo_id(hint: str) -> str:
    """Generate a WO ID from hint and timestamp."""
    ts = datetime.now().strftime("%Y%m%d-%H%M%S")
    hint_clean = hint.replace(" ", "-").upper()[:20] if hint else "AUTO"
    return f"WO-{hint_clean}-{ts}"


def parse_plan(plan: dict, dry_run: bool = True) -> dict:
    """
    Parse GMX plan and extract candidate WOs.
    
    Returns:
        {
            "status": "success" | "error",
            "dry_run": bool,
            "candidate_count": int,
            "candidates": [...],
            "skipped": [...],
            "errors": [...]
        }
    """
    result = {
        "status": "success",
        "dry_run": dry_run,
        "timestamp": datetime.now().isoformat(),
        "candidate_count": 0,
        "candidates": [],
        "skipped": [],
        "errors": [],
    }
    
    # Validate first
    is_valid, errors = validate_plan(plan)
    if not is_valid:
        result["status"] = "error"
        result["errors"] = errors
        return result
    
    # Process items
    for i, item in enumerate(plan.get("items", [])):
        item_type = item.get("type", "unknown")
        action = item.get("action", "noop")
        
        # Skip non-WO items
        if action != "create_wo":
            result["skipped"].append({
                "index": i,
                "type": item_type,
                "action": action,
                "reason": "action is not 'create_wo'",
            })
            continue
        
        # Extract WO suggestion
        wo_sug = item.get("wo_suggestion", {})
        wo_id = generate_wo_id(wo_sug.get("wo_id_hint", ""))
        
        candidate = {
            "wo_id": wo_id,
            "title": wo_sug.get("title", "Untitled"),
            "summary": wo_sug.get("summary", ""),
            "priority": item.get("priority", "medium"),
            "target": item.get("target", "unknown"),
            "tasks": wo_sug.get("tasks", []),
            "source": "gmx_orchestrator",
            "created_at": datetime.now().isoformat(),
        }
        
        result["candidates"].append(candidate)
        result["candidate_count"] += 1
        
        logger.info(f"Candidate WO: {wo_id} - {candidate['title']}")
    
    # Safety guardrail: v1 NEVER writes WOs
    if not dry_run:
        logger.warning("Non-dry-run mode requested but NOT ENABLED in v1. No WOs will be written.")
        result["warning"] = "Non-dry-run mode not enabled in v1. This is a safety guardrail."
    
    return result


# ═══════════════════════════════════════════
# Main
# ═══════════════════════════════════════════
def main():
    parser = argparse.ArgumentParser(
        description="GMX Plan Parser v1 - Parse orchestrator plans (dry-run only)"
    )
    parser.add_argument(
        "--input", "-i",
        required=True,
        help="Path to GMX plan JSON file",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        default=True,
        help="Dry-run mode (default: True, v1 always dry-run)",
    )
    parser.add_argument(
        "--output", "-o",
        help="Output file for results (default: stdout)",
    )
    parser.add_argument(
        "--quiet", "-q",
        action="store_true",
        help="Suppress stderr output",
    )
    
    args = parser.parse_args()
    
    # Read input file
    input_path = Path(args.input)
    if not input_path.exists():
        logger.error(f"Input file not found: {input_path}")
        sys.exit(1)
    
    try:
        with open(input_path, "r") as f:
            plan = json.load(f)
    except json.JSONDecodeError as e:
        logger.error(f"Invalid JSON in input file: {e}")
        sys.exit(1)
    
    # Parse plan
    logger.info(f"Parsing plan from: {input_path}")
    result = parse_plan(plan, dry_run=True)  # Always dry-run in v1
    
    # Output
    output_json = json.dumps(result, indent=2)
    
    if args.output:
        output_path = Path(args.output)
        with open(output_path, "w") as f:
            f.write(output_json)
        logger.info(f"Results written to: {output_path}")
    else:
        print(output_json)
    
    # Exit code
    if result["status"] == "error":
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    main()
