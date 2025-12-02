"""
Dev OSS Worker with direct-write capability via shared policy and pluggable OSS backend.
Enhanced with LAC v4 contract validation, telemetry, and QA handoff.

WO-DEV-001: Contract validation
WO-DEV-002: Telemetry
WO-QA-002: QA handoff integration
"""

from __future__ import annotations

import json
import threading
from typing import Any, Dict, List, Optional

from agents.dev_common.spec_consumer import (
    summarize_architect_spec,
    validate_architect_spec,
    validate_task_against_contract,
    load_developer_contract,
)
from agents.dev_common.telemetry import track_execution, log_dev_execution
from agents.dev_common.qa_handoff import run_qa_handoff
from agents.dev_common.reasoner_backend import OssLLMBackend, ReasonerBackend
from shared.policy import apply_patch, check_write_allowed

# Import MLS logging
try:
    from g.tools.mls_log import mls_log
except ImportError:
    # Silent failure if MLS not available
    def mls_log(*args, **kwargs):
        pass


class DevOSSWorker:
    """
    Dev OSS Worker - FREE lane for simple tasks (<3 files, no custom patterns).
    Uses DeepSeek/Qwen models (cost: $0).
    """
    
    LANE = "oss"
    
    def __init__(self, backend: Optional[ReasonerBackend] = None, enable_qa_handoff: bool = True):
        self.backend = backend or OssLLMBackend()
        self._contract = None
        self.enable_qa_handoff = enable_qa_handoff

    @property
    def contract(self) -> Dict[str, Any]:
        """Lazy load developer contract."""
        if self._contract is None:
            self._contract = load_developer_contract()
        return self._contract

    def validate_task(self, task: Dict[str, Any]) -> tuple[bool, str]:
        """
        Validate task against developer contract for OSS lane.
        WO-DEV-001 implementation.
        """
        return validate_task_against_contract(task, f"dev_{self.LANE}")

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
        # Pattern warnings shown whenever present, regardless of spec_summary availability
        # This ensures Dev sees risk signals even when architect spec validation fails
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
        """
        Execute task with contract validation, telemetry, and QA handoff.
        """
        task_id = task.get("wo_id", task.get("task_id", "unknown"))
        model_used = getattr(self.backend, "model_name", "deepseek-coder-v2")
        spec = task.get("architect_spec")
        
        # WO-DEV-001: Validate against contract
        is_valid, reason = self.validate_task(task)
        if not is_valid:
            # Log rejection to telemetry
            log_dev_execution(
                task_id=task_id,
                lane=self.LANE,
                contract_validated=False,
                model_used=model_used,
                spec_compliance=False,
                duration_ms=0,
                status="blocked",
                error_reason=reason,
            )
            return {
                "status": "blocked",
                "reason": reason,
                "lane": self.LANE,
                "wo_id": task_id,
                "qa_ran": False,
                "final_status": "blocked",
            }
        
        # WO-DEV-002: Track execution with telemetry
        with track_execution(task_id, self.LANE, model_used) as tracker:
            tracker["contract_validated"] = True
            tracker["files_touched"] = [] # Initialize
            
            # Reason and plan
            plan = self.reason(task)
            if isinstance(plan, dict) and plan.get("error"):
                tracker["status"] = "failed"
                tracker["error_reason"] = plan.get("error", "BACKEND_ERROR")
                return {
                    "status": "failed",
                    "reason": plan.get("error", "BACKEND_ERROR"),
                    "partial_results": [],
                    "wo_id": task_id,
                    "lane": self.LANE,
                    "qa_ran": False,
                    "final_status": "failed",
                }
            
            patches = self.generate_patches(plan)
            results = []
            
            for patch in patches:
                content = patch.get("content")
                if content is None or content == "":
                    tracker["status"] = "failed"
                    tracker["error_reason"] = "MISSING_OR_EMPTY_CONTENT"
                    return {
                        "status": "failed",
                        "reason": "MISSING_OR_EMPTY_CONTENT",
                        "file": patch["file"],
                        "partial_results": results,
                        "wo_id": task_id,
                        "lane": self.LANE,
                        "qa_ran": False,
                        "final_status": "failed",
                    }
                result = self.self_write(patch["file"], content)
                results.append(result)

                if result["status"] == "blocked":
                    tracker["status"] = "failed"
                    tracker["error_reason"] = result["reason"]
                    return {
                        "status": "failed",
                        "reason": result["reason"],
                        "partial_results": results,
                        "wo_id": task_id,
                        "lane": self.LANE,
                        "qa_ran": False,
                        "final_status": "failed",
                    }
                if result["status"] == "error":
                    tracker["status"] = "failed"
                    tracker["error_reason"] = result.get("reason", "FILE_WRITE_ERROR")
                    return {
                        "status": "failed",
                        "reason": result.get("reason", "FILE_WRITE_ERROR"),
                        "partial_results": results,
                        "wo_id": task_id,
                        "lane": self.LANE,
                        "qa_ran": False,
                        "final_status": "failed",
                    }
            
            tracker["spec_compliance"] = True
            
            # Build dev result
            files_touched = [r["file"] for r in results if r.get("status") == "success"]
            tracker["files_touched"] = files_touched
            
            dev_result = {
                "status": "success",
                "self_applied": True,
                "lane": self.LANE,
                "wo_id": task_id,
                "task_id": task_id,
                "files_touched": files_touched,
            }
            
            # WO-QA-002: QA handoff integration
            if self.enable_qa_handoff:
                final_result = run_qa_handoff(dev_result, spec)
                tracker["qa_status"] = final_result.get("qa_status", "unknown")
                tracker["final_status"] = final_result.get("final_status", "unknown")
                
                # Log to MLS (async, after workflow completes)
                threading.Thread(
                    target=mls_log,
                    args=(
                        "solution" if final_result.get("final_status") == "approved" else "failure",
                        f"Dev Worker ({self.LANE}): Task {task_id}",
                        f"Status: {final_result.get('final_status')}, Files: {len(files_touched)}, QA: {final_result.get('qa_status')}",
                        f"dev_worker_{self.LANE}"
                    ),
                    kwargs={
                        "state": {"files_touched": files_touched, "final_status": final_result.get("final_status")},
                        "tags": ["dev", self.LANE, "qa_handoff"],
                        "confidence": 0.9,
                        "wo_id": task_id
                    },
                    daemon=True
                ).start()
                
                return final_result
            else:
                dev_result["qa_ran"] = False
                dev_result["final_status"] = "success"
                return dev_result


__all__ = ["DevOSSWorker", "check_write_allowed", "apply_patch"]
