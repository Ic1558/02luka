from __future__ import annotations

from agents.architect.architect_agent import ArchitectAgent
from agents.qa_v4.qa_worker import QAWorkerV4


class PassingActions:
    def run_tests(self, target: str):
        return {"status": "success", "target": target}

    def run_lint(self, targets):
        return {"status": "success", "targets": targets}


def test_architect_includes_pattern_warnings(tmp_path, monkeypatch):
    pattern_db = tmp_path / "agents/rnd/pattern_db.yaml"
    pattern_db.parent.mkdir(parents=True, exist_ok=True)
    pattern_db.write_text("known_reasons:\n  - TEST_FAILED\n", encoding="utf-8")
    monkeypatch.setenv("LAC_PATTERN_DB", str(pattern_db))

    architect = ArchitectAgent()
    spec = architect.design({"wo_id": "REQ-TEST", "objective": "Test pattern warnings"})

    assert "pattern_warnings" in spec
    assert "TEST_FAILED" in spec["pattern_warnings"]


def test_qa_basic_checks_include_patterns(tmp_path, monkeypatch):
    pattern_db = tmp_path / "agents/rnd/pattern_db.yaml"
    pattern_db.parent.mkdir(parents=True, exist_ok=True)
    pattern_db.write_text("known_reasons:\n  - TEST_FAILED\n", encoding="utf-8")
    monkeypatch.setenv("LAC_BASE_DIR", str(tmp_path))

    worker = QAWorkerV4(actions=PassingActions())
    result = worker.execute_task(
        {
            "architect_spec": {
                "architecture": {"structure": {"modules": [{"files": []}]}},
            },
            "run_tests": False,
            "files_touched": [],
        }
    )

    assert result["status"] == "success"
    patterns = result["basic_checks"].get("patterns", [])
    assert "TEST_FAILED" in patterns
