"""
Checklist Engine - Evaluate QA results against checklists.

Supports:
1. Fixed internal checklist (agent's design)
2. ArchitectSpec qa_checklist (my design)

WO-QA-002 + Phase 5 Hardening
"""

from __future__ import annotations

from typing import Any, Dict, List, Optional


def evaluate_checklist(
    results: Dict[str, Any],
    architect_spec: Optional[Dict[str, Any]] = None,
    actions: Optional[Any] = None,
) -> Dict[str, Any]:
    """
    Evaluate QA results against checklist.
    
    Mode 1: Fixed checklist (from results dict)
    Mode 2: ArchitectSpec qa_checklist (if provided)
    
    Args:
        results: Dict with lint_success, test_success, security_issues, etc.
        architect_spec: Optional ArchitectSpec with qa_checklist
        actions: QaActions instance for running actionable items
    
    Returns:
        {
            "status": "pass" | "fail" | "warning",
            "checklist": {item: bool},
            "failed_ids": [...],
            "results": [...],
        }
    """
    # Mode 1: Fixed internal checklist
    if architect_spec is None or not architect_spec.get("qa_checklist"):
        return _evaluate_fixed_checklist(results)
    
    # Mode 2: ArchitectSpec qa_checklist
    return _evaluate_spec_checklist(architect_spec, actions)


def _evaluate_fixed_checklist(results: Dict[str, Any]) -> Dict[str, Any]:
    """
    Evaluate against fixed internal checklist.
    Agent's original design.
    """
    checklist = {
        "files_exist": results.get("files_exist", True),
        "lint_passed": results.get("lint_success", True),
        "tests_passed": results.get("test_success", True),
        "security_clean": len(results.get("security_issues", [])) == 0,
    }
    
    failed = [k for k, v in checklist.items() if not v]
    status = "pass" if not failed else "fail"
    
    return {
        "status": status,
        "checklist": checklist,
        "failed_ids": failed,
        "results": [
            {"id": k, "status": "pass" if v else "fail", "required": True}
            for k, v in checklist.items()
        ],
    }


def _evaluate_spec_checklist(
    architect_spec: Dict[str, Any],
    actions: Optional[Any] = None,
) -> Dict[str, Any]:
    """
    Evaluate against ArchitectSpec qa_checklist.
    My original design.
    
    Checklist item format:
    {
        "id": "lint-check",
        "type": "lint" | "automated_test" | "manual_review" | "structure",
        "command": "pytest tests/",
        "required": true,
        "description": "..."
    }
    """
    qa_checklist = architect_spec.get("qa_checklist", [])
    
    results: List[Dict[str, Any]] = []
    failed_ids: List[str] = []
    warnings: List[str] = []
    
    for item in qa_checklist:
        item_id = item.get("id", "unknown")
        item_type = (item.get("type") or "").lower()
        required = item.get("required", True)
        command = item.get("command")
        
        status = "pass"
        reason = None
        action_result = None
        
        try:
            if item_type == "lint" and actions:
                targets = command.split() if command else []
                action_result = actions.run_lint(targets)
                if not action_result.get("success"):
                    status = "fail"
                    reason = action_result.get("reason", "LINT_FAILED")
            
            elif item_type == "automated_test" and actions and command:
                action_result = actions.run_tests(command)
                if not action_result.get("success"):
                    status = "fail"
                    reason = action_result.get("reason", "TEST_FAILED")
            
            elif item_type == "security" and actions:
                targets = command.split() if command else []
                action_result = actions.run_security_check(targets)
                if not action_result.get("success"):
                    status = "fail"
                    reason = action_result.get("reason", "SECURITY_FAILED")
            
            elif item_type in ("manual_review", "structure", "pattern"):
                # Non-actionable items pass by default
                status = "pass"
                reason = "MANUAL_CHECK_ASSUMED_PASS"
            
            else:
                # Unknown type - skip
                status = "skipped"
                reason = f"UNKNOWN_TYPE: {item_type}"
        
        except Exception as exc:
            status = "fail"
            reason = f"CHECK_ERROR: {exc}"
        
        # Track failures
        if status == "fail" and required:
            failed_ids.append(item_id)
        elif status == "fail" and not required:
            warnings.append(item_id)
        
        results.append({
            "id": item_id,
            "type": item_type,
            "required": required,
            "status": status,
            "reason": reason,
            "action_result": action_result,
        })
    
    # Determine overall status
    if failed_ids:
        overall_status = "fail"
    elif warnings:
        overall_status = "warning"
    else:
        overall_status = "pass"
    
    return {
        "status": overall_status,
        "failed_ids": failed_ids,
        "warnings": warnings,
        "results": results,
        "checklist": {r["id"]: r["status"] == "pass" for r in results},
    }


__all__ = ["evaluate_checklist"]
