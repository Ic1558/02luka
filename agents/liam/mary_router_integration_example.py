#!/usr/bin/env python3
"""
Example: How to integrate Mary Router with GMX → Overseer → Cursor/Hybrid Shell

This shows the complete flow with all decision gates.
"""
from __future__ import annotations

from typing import Dict, Any

from agents.liam.mary_router import (
    enforce_overseer,
    apply_decision_gate,
    route_to_cursor,
    route_to_hybrid_shell,
)


def handle_gmx_task(task_spec: dict) -> dict:
    """
    Complete flow: GMX → Mary Router → Overseer → Cursor/Hybrid Shell
    
    This is the main entry point for GMX tasks.
    """
    intent = task_spec.get("intent", "")
    
    # ============================================================
    # STEP 1: Prepare payload based on intent
    # ============================================================
    
    if intent in ("refactor", "fix-bug", "add-feature", "generate-file"):
        # Patch operation - prepare patch metadata
        payload = {
            "changed_files": task_spec.get("target_files", []),
            "diff_text": task_spec.get("context", {}).get("description", ""),
        }
    elif intent == "run-command":
        # Shell operation - prepare command metadata
        payload = {
            "command": task_spec.get("command", ""),
            "task_spec": task_spec,
        }
    else:
        return {
            "status": "ERROR",
            "reason": f"Unknown intent: {intent}",
        }
    
    # ============================================================
    # STEP 2: Enforce Overseer (GMX → Mary Router → Overseer)
    # ============================================================
    
    decision = enforce_overseer(task_spec, payload)
    
    # ============================================================
    # STEP 3: Apply Decision Gate
    # ============================================================
    
    gate_result = apply_decision_gate(decision)
    
    if gate_result["status"] == "BLOCKED":
        return gate_result
    
    if gate_result["status"] == "REVIEW_REQUIRED":
        # Escalate to GM/Gemini advisor
        return {
            **gate_result,
            "next_action": "escalate_to_gm_advisor",
            "task_spec": task_spec,
        }
    
    # ============================================================
    # STEP 4: Route to execution (if approved)
    # ============================================================
    
    if intent in ("refactor", "fix-bug", "add-feature", "generate-file"):
        # Route to Cursor for patch generation
        return route_to_cursor(task_spec, payload)
    
    elif intent == "run-command":
        # Route to Hybrid Shell for command execution
        return route_to_hybrid_shell(payload)
    
    return {
        "status": "ERROR",
        "reason": f"Unhandled intent after approval: {intent}",
    }


# ============================================================
# USAGE EXAMPLES
# ============================================================

def example_patch_flow():
    """Example: Patch operation flow"""
    task_spec = {
        "intent": "refactor",
        "target_files": ["tools/test.py"],
        "context": {
            "description": "Refactor to use async/await",
        },
    }
    
    result = handle_gmx_task(task_spec)
    print("Patch flow result:", result)


def example_shell_flow():
    """Example: Shell command flow"""
    task_spec = {
        "intent": "run-command",
        "command": "docker compose up -d",
    }
    
    result = handle_gmx_task(task_spec)
    print("Shell flow result:", result)


def example_blocked_flow():
    """Example: Blocked operation"""
    task_spec = {
        "intent": "run-command",
        "command": "rm -rf /",
    }
    
    result = handle_gmx_task(task_spec)
    print("Blocked flow result:", result)


if __name__ == "__main__":
    print("=== Patch Flow ===")
    example_patch_flow()
    
    print("\n=== Shell Flow ===")
    example_shell_flow()
    
    print("\n=== Blocked Flow ===")
    example_blocked_flow()
