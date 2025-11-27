"""
Docs V4 Worker with direct-write capability for documentation files.
"""

from __future__ import annotations

from typing import Dict, List

from shared.policy import apply_patch, check_write_allowed


class DocsWorkerV4:
    def self_write(self, file_path: str, content: str) -> dict:
        """Direct write via shared policy."""
        return apply_patch(file_path, content)

    def write_doc_file(self, file_path: str, content: str) -> dict:
        """Write a documentation file using policy enforcement."""
        if content is None or content == "":
            return {
                "status": "failed",
                "reason": "MISSING_OR_EMPTY_CONTENT",
                "file": file_path,
            }
        return self.self_write(file_path, content)

    def plan_docs(self, task: Dict) -> Dict:
        return task.get("plan", task)

    def generate_doc_patches(self, plan: Dict) -> List[Dict]:
        return plan.get("patches", [])

    def execute_task(self, task: Dict) -> Dict:
        plan = self.plan_docs(task)
        patches = self.generate_doc_patches(plan)

        results = []
        for patch in patches:
            result = self.write_doc_file(patch["file"], patch.get("content", ""))
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


__all__ = ["DocsWorkerV4", "check_write_allowed", "apply_patch"]
