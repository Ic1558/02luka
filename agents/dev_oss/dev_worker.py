"""
Dev OSS Worker with direct-write capability via shared policy and pluggable OSS backend.
"""

from __future__ import annotations

import json
from typing import Any, Dict, List, Optional

from agents.dev_common.spec_consumer import summarize_architect_spec, validate_architect_spec
from agents.dev_common.reasoner_backend import OssLLMBackend, ReasonerBackend
from shared.policy import apply_patch, check_write_allowed


class DevOSSWorker:
    def __init__(self, backend: Optional[ReasonerBackend] = None):
        self.backend = backend or OssLLMBackend()

    def self_write(self, file_path: str, content: str) -> dict:
        """Direct write via shared policy."""
        return apply_patch(file_path, content)

    def reason(self, task: Dict[str, Any]) -> Dict[str, Any]:
        """
        Run reasoning via backend. If a plan is already provided, pass it through.
        """
        if "plan" in task:
            return task["plan"]
        if "patches" in task:
            return task

        prompt = self._build_prompt(task)
        try:
            response = self.backend.run(prompt, context=task)
        except Exception as exc:  # pragma: no cover - defensive guard
            return {"error": f"BACKEND_EXCEPTION: {exc}", "patches": []}

        parsed_plan = self._parse_response(response)
        if parsed_plan is not None:
            return parsed_plan

        return {
            "patches": [],
            "backend_answer": response.get("answer") if isinstance(response, dict) else "",
        }

    def _build_prompt(self, task: Dict[str, Any]) -> str:
        parts = [
            f"WO_ID: {task.get('wo_id', 'unknown')}",
            f"Objective: {task.get('objective', '')}",
            f"Routing: {task.get('routing_hint', '')}",
            f"Priority: {task.get('priority', '')}",
            f"Task_Content: {task.get('content', '')}",
        ]
        spec = task.get("architect_spec")
        spec_summary = summarize_architect_spec(spec) if spec and validate_architect_spec(spec) else ""
        if spec_summary:
            parts.append("ArchitectSpec:")
            parts.append(spec_summary)
        warnings = spec.get("pattern_warnings") if isinstance(spec, dict) else None
        if warnings:
            parts.append("PatternWarnings:")
            parts.append(", ".join(warnings))
        return "\n".join(parts)

    def _parse_response(self, response: Any) -> Optional[Dict[str, Any]]:
        if isinstance(response, dict):
            if response.get("status") == "error":
                return {"error": response.get("reason", "BACKEND_ERROR"), "patches": []}
            if "plan" in response:
                return response["plan"]
            if "patches" in response:
                return {"patches": response["patches"]}
            answer = response.get("answer")
            parsed = self._parse_answer(answer)
            if parsed is not None:
                return parsed
        elif isinstance(response, str):
            parsed = self._parse_answer(response)
            if parsed is not None:
                return parsed
        return None

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
        """Extract patches from plan."""
        return plan.get("patches", [])

    def execute_task(self, task: Dict) -> Dict:
        # Reason and plan
        plan = self.reason(task)
        if isinstance(plan, dict) and plan.get("error"):
            return {
                "status": "failed",
                "reason": plan.get("error", "BACKEND_ERROR"),
                "partial_results": [],
            }
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

        return {
            "status": "success",
            "self_applied": True,
            "files_touched": [
                r["file"] for r in results if r.get("status") == "success"
            ],
        }


__all__ = ["DevOSSWorker", "check_write_allowed", "apply_patch"]
