from __future__ import annotations

from typing import Any, Dict, List, Optional


def evaluate_checklist(architect_spec: Optional[Dict[str, Any]], actions: Any) -> Dict[str, Any]:
    """
    Evaluate QA checklist items from an Architect spec.
    Supports actionable types: automated_test, lint.
    Non-actionable items (structure/pattern/standards/manual_review) pass by default.
    """
    checklist = []
    if isinstance(architect_spec, dict):
        checklist = architect_spec.get("qa_checklist") or []

    results: List[Dict[str, Any]] = []
    failed_ids: List[str] = []

    for item in checklist:
        item_id = item.get("id", "")
        item_type = (item.get("type") or "").lower()
        required = item.get("required", True)
        command = item.get("command")
        status = "pass"
        reason = None
        action_result = None

        try:
            if item_type == "automated_test" and command:
                action_result = actions.run_tests(command)
                if action_result.get("status") != "success":
                    status = "fail"
                    reason = action_result.get("reason", "TEST_FAILED")
            elif item_type == "lint" and command:
                action_result = actions.run_lint([command])
                if action_result.get("status") != "success":
                    status = "fail"
                    reason = action_result.get("reason", "LINT_FAILED")
            else:
                # Non-actionable checklist items are treated as pass for now
                status = "pass"
        except Exception as exc:  # pragma: no cover - defensive
            status = "fail"
            reason = f"CHECK_EXEC_ERROR: {exc}"

        if required and status != "pass":
            failed_ids.append(item_id or item_type or "unknown")

        results.append(
            {
                "id": item_id,
                "type": item_type,
                "required": required,
                "status": status,
                "reason": reason,
                "action_result": action_result,
            }
        )

    overall_status = "pass" if not failed_ids else "fail"
    return {
        "status": overall_status,
        "failed_ids": failed_ids,
        "results": results,
    }


__all__ = ["evaluate_checklist"]
