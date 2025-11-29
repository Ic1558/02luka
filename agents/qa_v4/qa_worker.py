"""
QA V4 Worker with direct-write capability for test files.
"""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any, Dict, List, Optional

from agents.qa_v4.actions import QaActions
from agents.qa_v4.checklist_engine import evaluate_checklist
from shared.policy import apply_patch, check_write_allowed
from agents.rnd.pattern_learner import load_patterns


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
        # Evaluate checklist early for consistent response structure
        qa_actions_results = []
        checklist_result = evaluate_checklist(task.get("architect_spec"), self.actions)

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
                    "checklist": checklist_result,
                    "qa_actions": qa_actions_results,
                    "partial_results": results,
                }
            if result["status"] == "error":
                return {
                    "status": "failed",
                    "reason": result.get("reason", "FILE_WRITE_ERROR"),
                    "checklist": checklist_result,
                    "qa_actions": qa_actions_results,
                    "partial_results": results,
                }
            if result["status"] == "failed":
                return {
                    "status": "failed",
                    "reason": result.get("reason", "VALIDATION_FAILED"),
                    "checklist": checklist_result,
                    "qa_actions": qa_actions_results,
                    "partial_results": results,
                }
        if checklist_result["status"] != "pass":
            return {
                "status": "failed",
                "reason": "CHECKLIST_FAILED",
                "checklist": checklist_result,
                "qa_actions": qa_actions_results,
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
                    "checklist": checklist_result,
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
                    "checklist": checklist_result,
                    "qa_actions": qa_actions_results,
                    "partial_results": results,
                }

        files_for_checks = task.get("files_touched") or task.get("files") or []
        basic_result = self.run_basic_checks(files_for_checks, task.get("architect_spec"))
        if basic_result.get("status") != "success":
            return {
                "status": "failed",
                "reason": basic_result.get("reason", "BASIC_CHECKS_FAILED"),
                "qa_actions": qa_actions_results,
                "checklist": checklist_result,
                "basic_checks": basic_result,
                "partial_results": results,
            }

        telemetry = self._write_qa_telemetry(checklist_result, basic_result)

        return {
            "status": "success",
            "self_applied": True,
            "files_touched": [
                r["file"] for r in results if r.get("status") == "success"
            ],
            "qa_actions": qa_actions_results,
            "checklist": checklist_result,
            "basic_checks": basic_result,
            "telemetry": telemetry,
        }

    def run_basic_checks(self, files: List[str], architect_spec: Optional[Dict[str, Any]]) -> Dict[str, Any]:
        base_dir = self._base_dir()
        existing_files: List[str] = []
        for f in files:
            path = (base_dir / f).resolve()
            if path.exists():
                existing_files.append(str(path))

        lint_result = self.actions.run_lint(existing_files) if existing_files else {"status": "success", "skipped": True}
        if lint_result.get("status") != "success":
            return {"status": "failed", "reason": lint_result.get("reason", "LINT_FAILED"), "lint": lint_result}

        structure_result = self._structure_compliance(architect_spec)
        patterns = self._load_patterns()
        structure_result["pattern_warnings"] = patterns.get("known_reasons", [])
        status = "warn" if structure_result.get("pattern_warnings") else "success"
        return {"status": status, "lint": lint_result, "structure": structure_result}

    def _structure_compliance(self, architect_spec: Optional[Dict[str, Any]]) -> Dict[str, Any]:
        if not architect_spec:
            return {"status": "skipped"}

        modules = (architect_spec.get("architecture") or {}).get("structure", {}).get("modules", [])
        expected_files = []
        for module in modules:
            expected_files.extend(module.get("files", []))

        base_dir = self._base_dir()
        missing = []
        for f in expected_files:
            path = (base_dir / f).resolve()
            if not path.exists():
                missing.append(f)

        return {"status": "pass" if not missing else "warn", "missing": missing, "checked": expected_files}

    def _write_qa_telemetry(self, checklist: Dict[str, Any], basic: Dict[str, Any]) -> Dict[str, Any]:
        path = Path(os.getenv("LAC_QA_TELEMETRY_PATH") or self._base_dir() / "g/telemetry/qa_checklists.jsonl")
        record = {"checklist": checklist, "basic_checks": basic}
        try:
            path.parent.mkdir(parents=True, exist_ok=True)
            with path.open("a", encoding="utf-8") as handle:
                handle.write(json.dumps(record) + "\n")
            return {"status": "logged", "path": str(path)}
        except Exception as exc:
            return {"status": "error", "reason": str(exc)}

    def _base_dir(self) -> Path:
        base_dir = os.getenv("LAC_BASE_DIR")
        return Path(base_dir).resolve() if base_dir else Path.cwd().resolve()

    def _load_patterns(self) -> Dict[str, Any]:
        base_dir = self._base_dir()
        return load_patterns(base_dir / "agents/rnd/pattern_db.yaml")


__all__ = ["QAWorkerV4", "check_write_allowed", "apply_patch"]
