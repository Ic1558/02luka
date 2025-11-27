"""
QA V4 Worker with direct-write capability for test files.
"""

from __future__ import annotations

from typing import Dict, List

from shared.policy import apply_patch, check_write_allowed


class QAWorkerV4:
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

    def execute_task(self, task: Dict) -> Dict:
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

        return {
            "status": "success",
            "self_applied": True,
            "files_touched": [
                r["file"] for r in results if r.get("status") == "success"
            ],
        }


__all__ = ["QAWorkerV4", "check_write_allowed", "apply_patch"]
