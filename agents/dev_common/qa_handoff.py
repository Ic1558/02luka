"""
QA Handoff Module for LAC v4 Dev Workers.

Implements WO-QA-002: Dev Worker Integration with QA Lane.

Functions:
- prepare_qa_task(): Format dev result for QA worker
- should_handoff_to_qa(): Determine if QA handoff is needed
- handoff_to_qa(): Execute QA worker on dev result
- merge_qa_results(): Combine dev and QA results
- run_qa_handoff(): Full workflow convenience function
"""

from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

# Add project root to path
sys.path.insert(0, os.getcwd())

try:
    from agents.qa_v4 import QAWorkerV4  # Backward compatibility alias
    from agents.qa_v4.factory import create_worker_for_task
    from agents.qa_v4.mode_selector import log_mode_decision, calculate_qa_mode_score
except ImportError:
    QAWorkerV4 = None  # type: ignore
    create_worker_for_task = None  # type: ignore
    log_mode_decision = None  # type: ignore
    calculate_qa_mode_score = None  # type: ignore


def prepare_qa_task(
    dev_result: Dict[str, Any],
    spec: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    """
    Format dev result for QA worker.
    
    Args:
        dev_result: Result from dev worker execution
        spec: ArchitectSpec (optional, for QA checklist)
    
    Returns:
        QA task dict ready for QAWorkerV4.process_task()
    """
    wo_id = dev_result.get("wo_id", dev_result.get("task_id", "unknown"))
    
    qa_task = {
        "task_id": f"{wo_id}-qa",
        "wo_id": wo_id,
        "objective": f"QA validation for {wo_id}",
        "dev_result": dev_result,
        "files_touched": dev_result.get("files_touched", []),
        "routing_hint": "qa_v4",
        "priority": dev_result.get("priority", "normal"),
        "lane": dev_result.get("lane", "oss"),
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
    
    # Include architect spec if provided
    if spec:
        qa_task["architect_spec"] = spec
        qa_task["qa_checklist"] = spec.get("qa_checklist", [])
    
    # Include self-validation results if present
    if "self_validation" in dev_result:
        qa_task["self_validation"] = dev_result["self_validation"]
    
    return qa_task


def should_handoff_to_qa(dev_result: Dict[str, Any]) -> bool:
    """
    Determine if dev result should be handed off to QA.
    
    Args:
        dev_result: Result from dev worker execution
    
    Returns:
        True if QA handoff is needed
    """
    # Don't handoff if dev failed or was blocked
    status = dev_result.get("status", "").lower()
    if status in ("failed", "blocked", "error"):
        return False
    
    # Don't handoff if explicitly disabled
    if dev_result.get("skip_qa", False):
        return False
    
    # Don't handoff if no files were touched
    files_touched = dev_result.get("files_touched", [])
    if not files_touched:
        return False
    
    return True


def handoff_to_qa(
    qa_task: Dict[str, Any],
    wo_spec: Optional[Dict[str, Any]] = None,
    requirement: Optional[Dict[str, Any]] = None,
    history: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    """
    Execute QA worker on prepared QA task with intelligent mode selection.
    
    Args:
        qa_task: Task prepared by prepare_qa_task()
        wo_spec: Work order spec (optional, for mode override)
        requirement: Requirement doc (optional, for mode override)
        history: History data (optional, for auto-selection)
    
    Returns:
        QA execution result with mode metadata
    """
    # Fallback to old behavior if factory not available
    if create_worker_for_task is None:
        if QAWorkerV4 is None:
            return {
                "status": "skipped",
                "reason": "QAWorkerV4 not available (import failed)",
                "task_id": qa_task.get("task_id", "unknown"),
            }
        
        try:
            worker = QAWorkerV4()
            result = worker.process_task(qa_task)
            result["qa_mode_selected"] = "basic"  # Legacy mode
            result["qa_mode_reason"] = "legacy_qa_worker"
            return result
        except Exception as e:
            return {
                "status": "error",
                "reason": f"QA execution failed: {e}",
                "task_id": qa_task.get("task_id", "unknown"),
            }
    
    # Use factory with mode selection
    try:
        # Prepare task data for factory
        # Extract risk from dev_result if present
        dev_result_data = qa_task.get("dev_result", {})
        
        task_data = {
            "task_id": qa_task.get("task_id", "unknown"),
            "lane": qa_task.get("lane", "oss"),
            "files_touched": qa_task.get("files_touched", []),
            "architect_spec": qa_task.get("architect_spec"),
            "risk": dev_result_data.get("risk", qa_task.get("risk", {})),
            "qa": qa_task.get("qa", {}),
            "dev_result": dev_result_data,
            "history": history or {},
            "env": {"LAC_ENV": os.getenv("LAC_ENV", "dev")},
        }
        
        # Merge wo_spec and requirement if provided (highest priority)
        if wo_spec:
            if "risk" in wo_spec:
                task_data["risk"] = wo_spec.get("risk", task_data["risk"])
            if "qa" in wo_spec:
                task_data["qa"] = wo_spec.get("qa", task_data["qa"])
        if requirement:
            if isinstance(requirement, dict):
                if "risk" in requirement:
                    task_data["risk"] = requirement.get("risk", task_data["risk"])
                if "qa" in requirement:
                    task_data["qa"] = requirement.get("qa", task_data["qa"])
        
        # Select mode and create worker
        selected = create_worker_for_task(task_data)
        worker = selected["worker"]
        mode = selected["mode"]
        reason = selected["reason"]
        
        # Log mode decision to telemetry
        if log_mode_decision and calculate_qa_mode_score:
            score = calculate_qa_mode_score(
                wo_spec=wo_spec or {},
                requirement=requirement or {},
                dev_result=task_data.get("dev_result", {}),
                history=history or {},
                env=task_data.get("env", {}),
            )
            # Check for degradation (guardrails may have degraded mode)
            degraded = False
            degradation_reason = None
            try:
                from agents.qa_v4.guardrails import get_guardrails
                guardrails = get_guardrails()
                if guardrails:
                    # Check if mode was degraded by checking budget
                    # (We can't know for sure, but we can check if budget is exhausted)
                    budget_allowed, budget_reason = guardrails.check_budget(mode)
                    if not budget_allowed:
                        degraded = True
                        degradation_reason = budget_reason
            except ImportError:
                pass
            
            log_mode_decision(
                task_id=task_data["task_id"],
                mode=mode,
                reason=reason,
                score=score,
                override=bool(wo_spec and wo_spec.get("qa", {}).get("mode") or 
                             requirement and requirement.get("qa", {}).get("mode")),
                inputs={
                    "risk_level": task_data.get("risk", {}).get("level", "low"),
                    "domain": task_data.get("risk", {}).get("domain", "generic"),
                    "files_count": len(task_data.get("files_touched", [])),
                    "recent_failures": (history or {}).get("recent_qa_failures_for_module", 0),
                },
                degraded=degraded,
                degradation_reason=degradation_reason,
            )
        
        # Execute QA with performance monitoring
        start_time = time.time()
        result = worker.process_task(qa_task)
        execution_time = time.time() - start_time
        
        # Check performance and log warning if exceeded
        try:
            from agents.qa_v4.guardrails import get_guardrails
            guardrails = get_guardrails()
            if guardrails:
                perf_ok, perf_reason = guardrails.check_performance(mode, execution_time)
                if not perf_ok:
                    # Log warning (but don't fail QA)
                    if not isinstance(result, dict):
                        result = {"status": "error", "result": str(result)}
                    result.setdefault("warnings", []).append(
                        f"Performance warning: {perf_reason}"
                    )
        except ImportError:
            pass
        
        # Add mode metadata to result (ensure it's a dict)
        if not isinstance(result, dict):
            result = {"status": "error", "result": str(result)}
        
        result["qa_mode_selected"] = mode
        result["qa_mode_reason"] = reason
        result["qa_execution_time_seconds"] = round(execution_time, 2)
        
        return result
    except Exception as e:
        return {
            "status": "error",
            "reason": f"QA execution failed: {e}",
            "task_id": qa_task.get("task_id", "unknown"),
        }


def merge_qa_results(
    dev_result: Dict[str, Any],
    qa_result: Dict[str, Any],
) -> Dict[str, Any]:
    """
    Combine dev and QA results into final result.
    
    Args:
        dev_result: Original dev worker result
        qa_result: QA worker result
    
    Returns:
        Merged result with qa_status and final_status
    """
    merged = dict(dev_result)
    
    # Add QA-specific fields
    merged["qa_result"] = qa_result
    merged["qa_status"] = qa_result.get("status", "unknown")
    merged["qa_ran"] = True
    
    # Determine final status
    dev_status = dev_result.get("status", "unknown")
    qa_status = qa_result.get("status", "unknown")
    
    if dev_status == "success" and qa_status == "pass":
        merged["final_status"] = "approved"
    elif qa_status == "skipped":
        merged["final_status"] = dev_status  # QA skipped, use dev status
    elif qa_status in ("fail", "error"):
        merged["final_status"] = "qa_failed"
    else:
        merged["final_status"] = "unknown"
    
    # Add QA metadata
    merged["qa_checks"] = qa_result.get("checklist", {})
    merged["qa_issues"] = qa_result.get("issues", [])
    
    return merged


def run_qa_handoff(
    dev_result: Dict[str, Any],
    spec: Optional[Dict[str, Any]] = None,
    history: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    """
    Full QA handoff workflow: check -> prepare -> execute -> merge.
    
    Convenience function that combines all steps with intelligent mode selection.
    
    Args:
        dev_result: Result from dev worker
        spec: ArchitectSpec (optional, for QA checklist and mode override)
        history: History data (optional, for auto-selection)
    
    Returns:
        Merged result with QA status and mode metadata
    """
    if not should_handoff_to_qa(dev_result):
        # Return dev result as-is with QA skipped marker
        result = dict(dev_result)
        result["qa_ran"] = False
        result["qa_status"] = "skipped"
        result["final_status"] = dev_result.get("status", "unknown")
        return result
    
    qa_task = prepare_qa_task(dev_result, spec)
    
    # Pass spec as wo_spec/requirement for mode selection
    wo_spec = spec if spec else None
    requirement = spec if spec else None
    
    qa_result = handoff_to_qa(qa_task, wo_spec=wo_spec, requirement=requirement, history=history)
    merged = merge_qa_results(dev_result, qa_result)
    
    # Include mode metadata in merged result
    if "qa_mode_selected" in qa_result:
        merged["qa_mode_selected"] = qa_result["qa_mode_selected"]
        merged["qa_mode_reason"] = qa_result.get("qa_mode_reason", "")
    
    return merged


__all__ = [
    "prepare_qa_task",
    "should_handoff_to_qa",
    "handoff_to_qa",
    "merge_qa_results",
    "run_qa_handoff",
]
