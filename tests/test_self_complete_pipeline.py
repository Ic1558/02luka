import json
import os

import pytest

from agents.ai_manager.ai_manager import AIManager
from agents.qa_v4.qa_worker import QAWorkerV4


@pytest.fixture(autouse=True)
def set_completion_log(tmp_path, monkeypatch):
    monkeypatch.setenv("LAC_COMPLETIONS_LOG", str(tmp_path / "autonomous_completions.jsonl"))
    return tmp_path


def test_simple_work_order_direct_merge(set_completion_log):
    manager = AIManager()
    wo = {"wo_id": "WO-1", "self_apply": True, "complexity": "simple"}

    state = manager.transition(wo, "DEV_IN_PROGRESS", "DEV_DONE")
    assert state == "QA_IN_PROGRESS"

    state = manager.transition(wo, state, "QA_PASSED")
    assert state == "DOCS_IN_PROGRESS"

    state = manager.transition(wo, state, "DOCS_DONE")
    assert state == "DIRECT_MERGE"

    result = manager.handle_docs_completion(wo, files_touched=["g/src/a.py"])
    assert result["status"] == "success"
    assert result["merge_type"] == "DIRECT"
    assert wo["status"] == "COMPLETE"

    log_path = os.getenv("LAC_COMPLETIONS_LOG")
    assert log_path and os.path.exists(log_path)
    with open(log_path) as handle:
        record = json.loads(handle.readline())
        assert record["wo_id"] == "WO-1"
        assert record["used_clc"] is False


def test_complex_work_order_routes_to_clc():
    manager = AIManager()
    wo = {"wo_id": "WO-2", "self_apply": True, "complexity": "complex"}

    state = manager.transition(wo, "DOCS_DONE", None)
    assert state == "ROUTE_TO_CLC"

    result = manager.handle_docs_completion(wo, files_touched=["g/src/a.py"])
    assert result["status"] == "routed"
    assert result["next_state"] == "ROUTE_TO_CLC"
    assert wo.get("status") != "COMPLETE"


def test_multi_file_routes_to_clc_via_router():
    manager = AIManager()
    wo = {"wo_id": "WO-2b", "self_apply": True, "complexity": "simple", "file_count": 5}

    state = manager.transition(wo, "DOCS_DONE", None)
    assert state == "ROUTE_TO_CLC"

    result = manager.handle_docs_completion(wo, files_touched=["g/src/a.py"])
    assert result["status"] == "routed"
    assert result["next_state"] == "ROUTE_TO_CLC"
    assert wo.get("status") != "COMPLETE"


def test_qa_fail_returns_to_dev():
    manager = AIManager()
    wo = {"wo_id": "WO-3"}

    next_state = manager.transition(wo, "QA_FAILED", "QA_FAILED")
    assert next_state == "DEV_IN_PROGRESS"
    assert wo["qa_fail_count"] == 1


def test_qa_fail_three_times_escalates():
    manager = AIManager()
    wo = {"wo_id": "WO-4"}

    manager.transition(wo, "QA_FAILED", "QA_FAILED")
    manager.transition(wo, "QA_FAILED", "QA_FAILED")
    next_state = manager.transition(wo, "QA_FAILED", "QA_FAILED")

    assert next_state == "ESCALATE"
    assert wo["qa_fail_count"] == 3


def test_qa_worker_runs_tests_and_passes(monkeypatch):
    called = {"tests": 0, "lint": 0}

    class FakeActions:
        def run_lint(self, targets):
            called["lint"] += 1
            return {"status": "success"}

        def run_tests(self, target):
            called["tests"] += 1
            return {"status": "success"}

    worker = QAWorkerV4(actions=FakeActions())
    task = {"run_tests": True, "lint_targets": ["g/src/antigravity/core/hello.py"]}
    result = worker.execute_task(task)

    assert result["status"] == "success"
    assert called["tests"] == 1
    assert called["lint"] == 1
    assert result.get("qa_actions")  # should include action results


def test_qa_worker_runs_tests_and_fails(monkeypatch):
    class FakeActions:
        def run_lint(self, targets):
            return {"status": "success"}

        def run_tests(self, target):
            return {"status": "failed", "reason": "TEST_FAILED", "exit_code": 1}

    worker = QAWorkerV4(actions=FakeActions())
    task = {"run_tests": True}
    result = worker.execute_task(task)

    assert result["status"] == "failed"
    assert result["reason"] == "TEST_FAILED"
