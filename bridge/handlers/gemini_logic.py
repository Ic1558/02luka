#!/usr/bin/env python3
"""
Gemini Work Order Processing Logic

Pure business logic for processing Gemini work orders with Overseer safety checks.
Separated from gemini_handler.py for clarity and testability.
"""
from __future__ import annotations

import logging
import sys
from pathlib import Path
from typing import Any, Dict

# Setup path for imports
REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

REPO_ROOT_FOR_AGENTS = Path(__file__).resolve().parents[2]
if str(REPO_ROOT_FOR_AGENTS) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT_FOR_AGENTS))

from g.connectors import gemini_connector

logger = logging.getLogger(__name__)

# Mary Router integration
try:
    from agents.liam.mary_router import enforce_overseer, apply_decision_gate
    MARY_ROUTER_AVAILABLE = True
except ImportError:
    MARY_ROUTER_AVAILABLE = False
    logger.warning("Mary Router not available - overseer checks disabled")


def _normalize_payload(wo: Dict[str, Any]) -> Dict[str, Any]:
    """Extract and normalize payload from work order."""
    input_block = wo.get("input", {}) if isinstance(wo, dict) else {}
    
    return {
        "instructions": input_block.get("instructions", ""),
        "target_files": input_block.get("target_files", []),
        "context": input_block.get("context", {}),
        "command": wo.get("command") or input_block.get("command", ""),  # Support both top-level and input.command
    }


def _build_task_spec(task_type: str, payload: Dict[str, Any]) -> Dict[str, Any]:
    """Convert task_type and payload to task_spec format for Overseer."""
    # Map task_type to intent for overseer
    intent_map = {
        "code_transform": "refactor",
        "refactor": "refactor",
        "fix-bug": "fix-bug",
        "add-feature": "add-feature",
        "generate-file": "generate-file",
        "run-command": "run-command",
    }
    
    return {
        "intent": intent_map.get(task_type, task_type),
        "target_files": payload.get("target_files", []),
        "command": payload.get("command"),
        "context": payload.get("context", {}),
    }


def _check_overseer(task_spec: Dict[str, Any], payload: Dict[str, Any]) -> Dict[str, Any]:
    """Check with Overseer and return decision."""
    if not MARY_ROUTER_AVAILABLE:
        return {"approval": "Yes"}  # Allow if overseer unavailable
    
    intent = task_spec.get("intent", "")
    
    # Prepare patch_meta or task_meta based on intent
    if intent in ("refactor", "fix-bug", "add-feature", "generate-file"):
        patch_meta = {
            "changed_files": payload.get("target_files", []),
            "diff_text": payload.get("instructions", ""),
        }
        decision = enforce_overseer(task_spec, patch_meta)
    elif intent == "run-command":
        task_meta = {
            "command": payload.get("command", ""),
            "task_spec": task_spec,
        }
        decision = enforce_overseer(task_spec, task_meta)
    else:
        # Unknown intent → require review for safety
        decision = {
            "approval": "Review",
            "reason": f"Unknown intent '{intent}', manual review required.",
            "confidence_score": 0.5,
            "used_advisor": "Rule-Based",
            "trigger_details": ["unknown-intent"],
        }
    
    return decision


def _apply_decision_gate(decision: Dict[str, Any]) -> Dict[str, Any] | None:
    """Apply decision gate and return error response if blocked/review required, None if approved."""
    if not MARY_ROUTER_AVAILABLE:
        return None  # Proceed if overseer unavailable
    
    gate_result = apply_decision_gate(decision)
    
    if gate_result["status"] == "BLOCKED":
        return {
            "ok": False,
            "engine": "overseer",
            "status": "BLOCKED",
            "error": gate_result["reason"],
            "details": gate_result.get("details", []),
        }
    
    if gate_result["status"] == "REVIEW_REQUIRED":
        return {
            "ok": False,
            "engine": "overseer",
            "status": "REVIEW_REQUIRED",
            "reason": gate_result["reason"],
            "details": gate_result.get("details", []),
            "escalate_to": "gm-advisor",
        }
    
    # Approved - proceed
    return None


def _execute_gemini_task(task_type: str, payload: Dict[str, Any]) -> Dict[str, Any]:
    """Execute the Gemini task and return result."""
    result = gemini_connector.run_gemini_task(task_type, payload)
    return {
        "ok": True,
        "engine": "gemini",
        "task_type": task_type,
        "result": result,
    }


def handle_wo(wo: Dict[str, Any]) -> Dict[str, Any]:
    """
    Normalize a work order payload and execute it via the Gemini connector.
    
    This is the main entry point that coordinates:
    1. Payload normalization
    2. Overseer safety checks
    3. Decision gating
    4. Gemini task execution
    """
    task_type = wo.get("task_type", "code_transform")
    
    # Step 1: Normalize payload
    payload = _normalize_payload(wo)
    
    # Step 2: Build task_spec for Overseer
    task_spec = _build_task_spec(task_type, payload)
    
    # Step 3: Check with Overseer
    decision = _check_overseer(task_spec, payload)
    
    # Step 4: Apply decision gate
    gate_response = _apply_decision_gate(decision)
    if gate_response is not None:
        return gate_response
    
    # Step 5: If approved, log and proceed
    logger.info("Overseer approved task_type=%s, proceeding to Gemini", task_type)
    
    # Step 6: Execute Gemini task
    return _execute_gemini_task(task_type, payload)
