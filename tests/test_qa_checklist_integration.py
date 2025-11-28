from __future__ import annotations

from agents.qa_v4.checklist_engine import evaluate_checklist
from agents.qa_v4.qa_worker import QAWorkerV4


class PassingActions:
    def run_tests(self, target: str):
        return {"status": "success", "target": target}

    def run_lint(self, targets):
        return {"status": "success", "targets": targets}


class FailingActions:
    def run_tests(self, target: str):
        return {"status": "failed", "reason": "TEST_FAILED", "target": target}

    def run_lint(self, targets):
        return {"status": "failed", "reason": "LINT_FAILED", "targets": targets}


def test_checklist_passes_with_actions():
    spec = {
        "qa_checklist": [
            {"id": "test_001", "type": "automated_test", "command": "tests/demo"},
            {"id": "lint_001", "type": "lint", "command": "g/src/demo.py"},
            {"id": "pattern_001", "type": "pattern_check", "required": True},
        ]
    }
    result = evaluate_checklist(spec, PassingActions())
    assert result["status"] == "pass"
    assert not result["failed_ids"]


def test_checklist_fails_on_required_item():
    spec = {
        "qa_checklist": [
            {"id": "test_001", "type": "automated_test", "command": "tests/demo", "required": True},
            {"id": "lint_001", "type": "lint", "command": "g/src/demo.py", "required": False},
        ]
    }
    result = evaluate_checklist(spec, FailingActions())
    assert result["status"] == "fail"
    assert "test_001" in result["failed_ids"]


def test_qa_worker_consumes_checklist():
    spec = {
        "qa_checklist": [
            {"id": "lint_001", "type": "lint", "command": "g/src/demo.py", "required": True}
        ]
    }
    worker = QAWorkerV4(actions=PassingActions())
    task = {"architect_spec": spec, "run_tests": False}
    result = worker.execute_task(task)
    assert result["status"] == "success"
    assert result["checklist"]["status"] == "pass"
