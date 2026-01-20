"""
Placeholder Dev Codex Worker following the same pattern as other dev lanes.
TODO: Wire to Codex IDE backend once available.
"""

from __future__ import annotations

import json
from typing import Any, Dict, List, Optional

from agents.dev_common.spec_consumer import summarize_architect_spec, validate_architect_spec
from agents.dev_common.reasoner_backend import OssLLMBackend, ReasonerBackend
from shared.policy import apply_patch, check_write_allowed


class DevCodexWorker:
    def __init__(self, backend: Optional[ReasonerBackend] = None):
        self.backend = backend or OssLLMBackend()

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
        # Pattern warnings shown whenever present, regardless of spec_summary availability
        # This ensures Dev sees risk signals even when architect spec validation fails
        warnings = spec.get("pattern_warnings") if isinstance(spec, dict) else None
        if warnings:
            parts.append("PatternWarnings:")
            parts.append(", ".join(warnings))
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
        task_id = task.get("wo_id") or task.get("id") or task.get("objective")
        summary = task.get("objective") or task.get("summary") or task_id or "task"
        lane_name = "dev"
        try:
            from g.tools.core_intake import build_intake, render_text

            brief = render_text(build_intake(task_id=task_id, summary=summary))
            for line in brief.splitlines()[:3]:
                print(f"[CORE INTAKE] {line}")
        except Exception:
            pass

        def write_note(status: str, artifact_path: Optional[str] = None) -> None:
            if not task_id:
                return
            try:
                from bridge.lac.writer import write_work_note

                write_work_note(
                    lane_name,
                    str(task_id),
                    str(summary),
                    status,
                    artifact_path=artifact_path,
                )
            except Exception:
                pass

        plan = self.reason(task)
        patches = self.generate_patches(plan)

        results = []
        for patch in patches:
            content = patch.get("content")
            if content is None or content == "":
                write_note("error", artifact_path=patch.get("file"))
                return {
                    "status": "failed",
                    "reason": "MISSING_OR_EMPTY_CONTENT",
                    "file": patch["file"],
                    "partial_results": results,
                }
            result = self.self_write(patch["file"], content)
            results.append(result)
            if result["status"] == "blocked":
                write_note("error", artifact_path=patch.get("file"))
                return {
                    "status": "failed",
                    "reason": result["reason"],
                    "partial_results": results,
                }
            if result["status"] == "error":
                write_note("error", artifact_path=patch.get("file"))
                return {
                    "status": "failed",
                    "reason": result.get("reason", "FILE_WRITE_ERROR"),
                    "partial_results": results,
                }
            if result["status"] == "failed":
                write_note("error", artifact_path=patch.get("file"))
                return {
                    "status": "failed",
                    "reason": result.get("reason", "VALIDATION_FAILED"),
                    "partial_results": results,
                }

        artifact_path = None
        if results:
            artifact_path = results[0].get("file")
        write_note("success", artifact_path=artifact_path)
        return {
            "status": "success",
            "self_applied": True,
            "files_touched": [
                r["file"] for r in results if r.get("status") == "success"
            ],
        }


__all__ = ["DevCodexWorker", "check_write_allowed", "apply_patch"]
