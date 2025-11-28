"""
QA V4 Worker with direct-write capability for test files.
"""

from __future__ import annotations

from typing import Any, Dict, List, Optional

from agents.qa_v4.actions import QaActions
from agents.qa_v4.checklist_engine import evaluate_checklist
from shared.policy import apply_patch, check_write_allowed


class QAWorkerV4:
    def __init__(self, actions: Optional[QaActions] = None):
        self.actions = actions or QaActions()

    def self_write(self, file_path: str, content: str) -> dict:
        """Direct write via shared policy."""
        return apply_patch(file_path, content)

    def write_test_file(self, file_path: str, content: str) -> dict:
        """Write a test file using policy enforcement."""
        if content is None or content == "":
            return {
                "status": "failed",
                "reason": "MISSING_OR_EMPTY_CONTENT",
                "file": file_path,
            }
        return self.self_write(file_path, content)

    def plan_tests(self, task: Dict) -> Dict:
        """Placeholder planning for tests."""
        return task.get("plan", task)

    def generate_test_patches(self, plan: Dict) -> List[Dict]:
        return plan.get("patches", [])

    def execute_task(self, task: Dict[str, Any]) -> Dict:
        plan = self.plan_tests(task)
        patches = self.generate_test_patches(plan)

        results = []
        for patch in patches:
            result = self.write_test_file(patch["file"], patch.get("content", ""))
            results.append(result)
            if result["status"] == "blocked":
                return {
                    "status": "failed",
                    "reason": result["reason"],
                    "partial_results": results,
                }
            if result["status"] == "error":
                return {
                    "status": "failed",
                    "reason": result.get("reason", "FILE_WRITE_ERROR"),
                    "partial_results": results,
                }
            if result["status"] == "failed":
                return {
                    "status": "failed",
                    "reason": result.get("reason", "VALIDATION_FAILED"),
                    "partial_results": results,
                }

        qa_actions_results = []
        checklist_result = evaluate_checklist(task.get("architect_spec"), self.actions)
        if checklist_result["status"] != "pass":
            return {
                "status": "failed",
                "reason": "CHECKLIST_FAILED",
                "checklist": checklist_result,
                "partial_results": results,
            }

        # Optional lint
        lint_targets = task.get("lint_targets") or []
        if lint_targets:
            lint_result = self.actions.run_lint(lint_targets)
            qa_actions_results.append({"action": "lint", **lint_result})
            if lint_result.get("status") != "success":
                return {
                    "status": "failed",
                    "reason": lint_result.get("reason", "LINT_FAILED"),
                    "qa_actions": qa_actions_results,
                    "partial_results": results,
                }

        # Optional tests
        if task.get("run_tests"):
            test_target = task.get("test_target", "tests")
            test_result = self.actions.run_tests(test_target)
            qa_actions_results.append({"action": "tests", **test_result})
            if test_result.get("status") != "success":
                return {
                    "status": "failed",
                    "reason": test_result.get("reason", "TEST_FAILED"),
                    "qa_actions": qa_actions_results,
                    "partial_results": results,
                }

        return {
            "status": "success",
            "self_applied": True,
            "files_touched": [
                r["file"] for r in results if r.get("status") == "success"
            ],
            "qa_actions": qa_actions_results,
            "checklist": checklist_result,
        }


__all__ = ["QAWorkerV4", "check_write_allowed", "apply_patch"]
