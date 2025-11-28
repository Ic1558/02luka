"""
Placeholder Dev Codex Worker following the same pattern as other dev lanes.
TODO: Wire to Codex IDE backend once available.
"""

from __future__ import annotations

import json
from typing import Any, Dict, List, Optional

from agents.dev_common.spec_consumer import summarize_architect_spec, validate_architect_spec
from agents.dev_common.reasoner_backend import CodexBackend, ReasonerBackend
from shared.policy import apply_patch, check_write_allowed


class DevCodexWorker:
    def __init__(self, backend: Optional[ReasonerBackend] = None):
        self.backend = backend or CodexBackend()

    def self_write(self, file_path: str, content: str) -> dict:
        """Direct write via shared policy."""
        return apply_patch(file_path, content)

    def reason(self, task: Dict[str, Any]) -> Dict[str, Any]:
        """
        Run reasoning via configured backend if present; otherwise pass through plan.
        """
        if "plan" in task:
            return task["plan"]
        if self.backend:
            response = self.backend.run(self._build_prompt(task), context=task)
            if isinstance(response, dict):
                if response.get("status") == "error":
                    return {"error": response.get("reason", "BACKEND_ERROR"), "patches": []}
                if "plan" in response:
                    return response["plan"]
                if "patches" in response:
                    return {"patches": response["patches"]}
                parsed = self._parse_answer(response.get("answer"))
                if parsed is not None:
                    return parsed
            else:
                parsed = self._parse_answer(response)
                if parsed is not None:
                    return parsed
        return {"patches": []}

    def _build_prompt(self, task: Dict[str, Any]) -> str:
        parts = [
            f"WO_ID: {task.get('wo_id', 'unknown')}",
            f"Objective: {task.get('objective', '')}",
            f"Routing: {task.get('routing_hint', '')}",
            f"Priority: {task.get('priority', '')}",
        ]
        spec = task.get("architect_spec")
        spec_summary = summarize_architect_spec(spec) if spec and validate_architect_spec(spec) else ""
        if spec_summary:
            parts.append("ArchitectSpec:")
            parts.append(spec_summary)
        return "\n".join(parts)

    def _parse_answer(self, answer: Any) -> Optional[Dict[str, Any]]:
        if not isinstance(answer, str):
            return None
        try:
            as_json = json.loads(answer)
        except json.JSONDecodeError:
            return None
        if isinstance(as_json, dict):
            if "plan" in as_json:
                return as_json["plan"]
            if "patches" in as_json:
                return {"patches": as_json["patches"]}
        return None

    def generate_patches(self, plan: Dict) -> List[Dict]:
        return plan.get("patches", [])

    def execute_task(self, task: Dict) -> Dict:
        plan = self.reason(task)
        patches = self.generate_patches(plan)

        results = []
        for patch in patches:
            content = patch.get("content")
            if content is None or content == "":
                return {
                    "status": "failed",
                    "reason": "MISSING_OR_EMPTY_CONTENT",
                    "file": patch["file"],
                    "partial_results": results,
                }
            result = self.self_write(patch["file"], content)
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


__all__ = ["DevCodexWorker", "check_write_allowed", "apply_patch"]
