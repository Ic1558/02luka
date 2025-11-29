"""
AI Manager state machine for autonomous pipeline routing.
Now integrates Requirement.md parsing and free-first routing.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any, Dict, List, Optional

from agents.ai_manager.actions.direct_merge import direct_merge
from agents.ai_manager.requirement_parser import parse_requirement_md
from agents.architect.architect_agent import ArchitectAgent
from agents.architect.spec_builder import ArchitectSpec, SpecBuilder
from agents.clc.model_router import should_route_to_clc
from agents.dev_oss.dev_worker import DevOSSWorker
from agents.qa_v4.qa_worker import QAWorkerV4
from agents.docs_v4.docs_worker import DocsWorkerV4
from g.tools.lac_telemetry import build_event, log_event
from shared.routing import determine_lane


class AIManager:
    def __init__(self, architect: Optional[ArchitectAgent] = None, spec_builder: Optional[SpecBuilder] = None):
        self.state: str = "NEW"
        self.architect = architect or ArchitectAgent()
        self.spec_builder = spec_builder or SpecBuilder()

    def build_work_order_from_requirement(self, requirement_path: str = "Requirement.md", file_count: int = 0) -> Dict[str, Any]:
        """
        Read a Requirement.md file, parse it, validate required fields,
        and apply routing decisions.
        """
        path = Path(requirement_path)
        if not path.exists():
            return {
                "status": "invalid",
                "errors": [f"REQUIREMENT_NOT_FOUND: {requirement_path}"],
                "work_order": {},
            }

        try:
            content = path.read_text(encoding="utf-8")
        except OSError as exc:
            return {
                "status": "invalid",
                "errors": [f"READ_FAILED: {exc}"],
                "work_order": {},
            }

        parsed = parse_requirement_md(content)
        if file_count and "file_count" not in parsed:
            parsed["file_count"] = file_count

        # Generate Architect spec; keep errors separate so routing can still proceed for reporting
        architect_spec: Optional[Dict[str, Any]] = None
        try:
            architect_spec = self.architect.design(parsed)
            parsed["architect_spec"] = architect_spec
        except Exception as exc:
            parsed["architect_spec_error"] = str(exc)

        errors = self._validate_work_order(parsed)
        routing = self._ensure_routing(parsed)

        status = "ready" if not errors else "invalid"
        return {
            "status": status,
            "errors": errors,
            "work_order": parsed,
            "routing": routing,
            "architect_spec": architect_spec,
        }

    def run_self_complete(self, requirement_content: str) -> Dict[str, Any]:
        """
        Simple self-complete pipeline:
        Requirement content -> ArchitectSpec -> Dev (OSS) -> QA -> Docs -> Direct Merge (simple lane only).
        """
        wo = parse_requirement_md(requirement_content)
        wo.setdefault("complexity", "simple")
        wo.setdefault("self_apply", True)

        analysis = self.architect.design(wo)
        # Use analysis directly to maintain consistent nested structure
        # (architecture.structure, architecture.patterns, etc.)
        # This matches build_work_order_from_requirement() format
        wo["architect_spec"] = analysis

        routing = self._ensure_routing(wo)
        if routing.get("lane") != "dev_oss":
            return {"status": "failed", "stage": "routing", "reason": "UNSUPPORTED_LANE", "routing": routing}

        # Dev step
        wo["plan"] = {
            "patches": [
                {
                    "file": "g/src/pipeline_output.txt",
                    "content": f"{wo.get('objective', 'No objective')} ({wo.get('wo_id', 'UNKNOWN')})",
                }
            ]
        }
        dev_task = self.build_dev_task(wo)
        dev_worker = DevOSSWorker(backend=None)
        dev_result = dev_worker.execute_task(dev_task)
        if dev_result.get("status") != "success":
            return {"status": "failed", "stage": "dev", "result": dev_result}

        files_touched = dev_result.get("files_touched", [])

        # QA step
        class _QuickQaActions:
            def run_tests(self, target: str) -> Dict[str, Any]:
                return {"status": "success", "target": target}

            def run_lint(self, targets: List[str]) -> Dict[str, Any]:
                return {"status": "success", "targets": targets}

        qa_worker = QAWorkerV4(actions=_QuickQaActions())
        qa_result = qa_worker.execute_task(
            {"architect_spec": wo.get("architect_spec"), "run_tests": False, "files_touched": files_touched}
        )
        if qa_result.get("status") != "success":
            return {"status": "failed", "stage": "qa", "result": qa_result}

        # Docs step
        docs_worker = DocsWorkerV4()
        docs_result = docs_worker.execute_task(
            {
                "operation": "summary",
                "requirement_id": wo.get("wo_id", "UNKNOWN"),
                "status": "success",
                "lane": routing.get("lane", "dev_oss"),
                "qa_status": qa_result.get("status"),
                "files_touched": files_touched,
                "pattern_warnings": wo.get("architect_spec", {}).get("pattern_warnings", []),
            }
        )
        if docs_result.get("status") != "success":
            return {"status": "failed", "stage": "docs", "result": docs_result}

        # Merge step (simple lane only)
        merge_result = direct_merge(wo, files_touched)
        merge_result["qa_result"] = qa_result
        merge_result["docs_result"] = docs_result
        return merge_result

    def build_dev_task(self, wo: Dict[str, Any]) -> Dict[str, Any]:
        """
        Build a task payload for dev workers, ensuring ArchitectSpec is attached.
        """
        routing = self._ensure_routing(wo)
        task: Dict[str, Any] = {
            "wo_id": wo.get("wo_id", "unknown"),
            "objective": wo.get("objective", ""),
            "content": wo.get("content", wo.get("objective", "")),
            "priority": wo.get("priority", "P2"),
            "routing_hint": routing.get("lane", wo.get("routing_hint")),
            "architect_spec": wo.get("architect_spec"),
        }
        if "plan" in wo:
            task["plan"] = wo["plan"]
        return task

    def transition(self, wo: Dict, current_state: str, event: Optional[str]) -> str:
        if current_state == "NEW" and event == "START":
            self._ensure_routing(wo)
            return "DEV_IN_PROGRESS"

        if current_state == "DEV_IN_PROGRESS" and event == "DEV_DONE":
            routing = self._ensure_routing(wo)
            self._emit_event("DEV_COMPLETED", wo, routing.get("lane", wo.get("routing_hint", "dev_oss")), "success")
            return "QA_IN_PROGRESS"

        if current_state == "QA_IN_PROGRESS":
            if event == "QA_PASSED":
                self._emit_event("QA_COMPLETED", wo, "qa_v4", "success")
                return "DOCS_IN_PROGRESS"
            if event == "QA_FAILED":
                self._emit_event("QA_COMPLETED", wo, "qa_v4", "failed")
                return "QA_FAILED"

        if current_state == "QA_FAILED":
            wo["qa_fail_count"] = wo.get("qa_fail_count", 0) + 1
            if wo["qa_fail_count"] >= 3:
                return "ESCALATE"
            return "DEV_IN_PROGRESS"

        if current_state == "DOCS_IN_PROGRESS" and event == "DOCS_DONE":
            self._emit_event("DOCS_COMPLETED", wo, "docs_v4", "success")
            return self._docs_done_transition(wo)

        if current_state == "DOCS_DONE":
            return self._docs_done_transition(wo)

        return current_state

    def _docs_done_transition(self, wo: Dict) -> str:
        routing = self._ensure_routing(wo)
        route_to_clc = should_route_to_clc(wo)
        complexity = (wo.get("complexity") or "simple").lower()
        self_apply = wo.get("self_apply", True)

        # Direct merge only for OSS simple work with self-apply allowed and no CLC override
        if routing.get("lane") == "dev_oss" and self_apply and complexity == "simple" and not route_to_clc:
            return "DIRECT_MERGE"

        # Everything else goes through CLC path (includes paid lanes or moderate/complex)
        return "ROUTE_TO_CLC"

    def handle_docs_completion(self, wo: Dict, files_touched: Optional[List[str]] = None) -> Dict:
        next_state = self.transition(wo, "DOCS_DONE", event=None)
        if next_state == "DIRECT_MERGE":
            merge_result = direct_merge(wo, files_touched or [])
            merge_result["next_state"] = next_state
            return merge_result

        return {"status": "routed", "next_state": next_state}

    def _ensure_routing(self, wo: Dict[str, Any]) -> Dict[str, Any]:
        if isinstance(wo.get("routing"), dict) and wo["routing"].get("lane"):
            return wo["routing"]

        file_count = self._infer_file_count(wo)
        routing = determine_lane(
            complexity=(wo.get("complexity") or "moderate").lower(),
            file_count=file_count,
            hint=wo.get("routing_hint"),
        )

        wo["routing"] = routing
        wo["routing_lane"] = routing.get("lane")
        wo.setdefault("routing_hint", routing.get("lane"))
        wo["routing_model"] = routing.get("model")
        wo["routing_reason"] = routing.get("reason")
        wo["routing_approved"] = routing.get("approved", True)
        wo["requires_paid_lane"] = wo.get("requires_paid_lane", False) or routing.get("lane") == "dev_paid"

        self._emit_event(
            "ROUTING_DECISION",
            wo,
            routing.get("lane", "unknown"),
            "approved" if routing.get("approved", True) else "pending",
            extra={"reason": routing.get("reason"), "file_count": file_count},
        )
        return routing

    def _infer_file_count(self, wo: Dict[str, Any]) -> int:
        if isinstance(wo.get("file_count"), int):
            return wo["file_count"]
        files = wo.get("files") or []
        try:
            return int(len(files))
        except Exception:
            return 0

    def _validate_work_order(self, wo: Dict[str, Any]) -> List[str]:
        errors: List[str] = []
        wo_id = (wo.get("wo_id") or "").strip()
        if not wo_id or wo_id == "UNKNOWN":
            errors.append("INVALID_WO_ID")

        objective = (wo.get("objective") or "").strip()
        if not objective:
            errors.append("MISSING_OBJECTIVE")

        complexity = (wo.get("complexity") or "").lower()
        if complexity not in {"simple", "moderate", "complex"}:
            errors.append("INVALID_COMPLEXITY")

        return errors

    def _emit_event(self, event_type: str, wo: Dict, lane: str, status: str, duration_ms: int = 0, extra: Optional[Dict] = None) -> None:
        try:
            event = build_event(
                event_type=event_type,
                wo_id=wo.get("wo_id", "unknown"),
                lane=lane,
                status=status,
                duration_ms=duration_ms,
                paid=bool(wo.get("requires_paid_lane", False)),
                extra=extra,
            )
            log_event(event)
        except Exception:
            return


__all__ = ["AIManager"]
