#!/usr/bin/env python3
"""
Mary Router - GMX Safety Entrypoint
Connects GMX task_spec → Overseer → Cursor/Hybrid Shell
"""
from __future__ import annotations

import os
import sys
from typing import Dict, Any, Optional

# Ensure we can import from tools
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "../../")))

from governance.overseerd import decide_for_patch, decide_for_shell
from tools.ap_io_v31.writer import write_ledger_entry


# --- GMX SAFETY ENTRYPOINT ---

def enforce_overseer(task_spec: dict, payload: dict) -> dict:
    """
    task_spec: gmx JSON spec
    payload: generated patch or shell command metadata
    
    Returns decision dict with approval, reason, trigger_details
    """
    intent = task_spec.get("intent", "")
    parent_id = task_spec.get("parent_id")
    
    decision = _get_overseer_decision(intent, task_spec, payload)
    
    # AP/IO Logging
    write_ledger_entry(
        agent="Liam",
        event="overseer_check",
        data={
            "intent": intent,
            "decision": decision
        },
        parent_id=parent_id
    )
    
    return decision


def _get_overseer_decision(intent: str, task_spec: dict, payload: dict) -> dict:
    """Internal helper to get decision without logging"""
    # patch case
    if intent in ("refactor", "fix-bug", "add-feature", "generate-file"):
        return decide_for_patch(task_spec, payload)
    
    # shell case
    if intent == "run-command":
        return decide_for_shell(payload)
    
    # default: allow (no overseer rule for this intent)
    return {
        "approval": "Yes",
        "reason": "No overseer rule for this intent.",
        "confidence_score": 1.0,
        "used_advisor": "Rule-Based",
        "trigger_details": [],
    }


def apply_decision_gate(decision: dict) -> dict:
    """
    Apply decision gate based on overseer decision.
    Returns status dict for Mary Router to handle.
    """
    # SECURE DEFAULT: Default to BLOCKED if approval is missing or unknown
    approval = decision.get("approval", "BLOCKED")
    
    if approval == "No":
        return {
            "status": "BLOCKED",
            "reason": decision.get("reason", "Blocked by overseer"),
            "details": decision.get("trigger_details", []),
            "confidence_score": decision.get("confidence_score", 0.95),
        }
    
    if approval == "Review":
        # escalate to GMX/Gemini/Advisor
        return {
            "status": "REVIEW_REQUIRED",
            "reason": decision.get("reason", "Review required"),
            "details": decision.get("trigger_details", []),
            "escalate_to": "gm-advisor",
            "confidence_score": decision.get("confidence_score", 0.6),
        }
    
    if approval == "Yes":
        return {
            "status": "APPROVED",
            "reason": decision.get("reason", "Approved by overseer"),
            "confidence_score": decision.get("confidence_score", 1.0),
        }
        
    # Fallback for unknown approval status
    return {
        "status": "BLOCKED",
        "reason": f"Unknown approval status: {approval}",
        "details": [],
        "confidence_score": 1.0,
    }


def route_to_cursor(task_spec: dict, patch_meta: dict) -> dict:
    """
    Route patch generation to Cursor.
    Call this after overseer approval for patch intents.
    """
    intent = task_spec.get("intent", "")
    
    if intent in ("refactor", "fix-bug", "add-feature", "generate-file"):
        # Log the routing event
        write_ledger_entry(
            agent="Liam",
            event="route_to_cursor",
            data={"task_spec": task_spec},
            parent_id=task_spec.get("parent_id")
        )
        
        return {
            "status": "PATCH_READY",
            "patch": None,  # placeholder - replace with actual patch
            "task_spec": task_spec,
            "patch_meta": patch_meta,
        }
    
    return {
        "status": "SKIPPED",
        "reason": f"Intent '{intent}' not a patch operation",
    }


def route_to_hybrid_shell(task_meta: dict) -> dict:
    """
    Route shell command to Hybrid Shell.
    Call this after overseer approval for run-command intent.
    """
    command = task_meta.get("command", "")
    task_spec = task_meta.get("task_spec", {})
    
    if not command:
        return {
            "status": "ERROR",
            "reason": "No command provided",
        }
    
    # Log the routing event
    write_ledger_entry(
        agent="Liam",
        event="route_to_hybrid_shell",
        data={"command": command},
        parent_id=task_spec.get("parent_id")
    )
    
    return {
        "status": "COMMAND_READY",
        "command": command,
        "result": None,  # placeholder - replace with actual result
    }

def init_task_state(task_spec: dict) -> str:
    """
    Initialize the task state in task.md.
    Returns the path to the task file.
    """
    task_file = os.path.abspath("task.md")
    
    intent = task_spec.get("intent", "unknown-intent")
    parent_id = task_spec.get("parent_id", "no-parent")
    
    # Basic template
    content = f"# Task: {intent}\n\nParent ID: {parent_id}\n\n- [ ] Analyze Request <!-- id: 0 -->\n- [ ] Execute Intent: {intent} <!-- id: 1 -->\n- [ ] Verify Results <!-- id: 2 -->\n"

    # If context has steps, use them
    context = task_spec.get("context", {})
    if "steps" in context:
        content = f"# Task: {intent}\n\nParent ID: {parent_id}\n\n"
        for i, step in enumerate(context["steps"]):
            action = step.get("action", "unknown")
            content += f"- [ ] Step {i}: {action} <!-- id: {i} -->\n"

    with open(task_file, "w") as f:
        f.write(content)
        
    return task_file
