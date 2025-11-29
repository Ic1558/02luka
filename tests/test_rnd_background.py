from __future__ import annotations

from agents.rnd.failure_analyzer import analyze_failures
from agents.rnd.pattern_learner import load_patterns, update_patterns
from agents.rnd.rnd_agent import RnDAgent
from shared.scheduler import Scheduler


def test_rnd_agent_runs_and_updates(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    agent = RnDAgent(pattern_db_path=tmp_path / "pattern_db.yaml")
    failures = [{"reason": "TEST_FAILED"}, {"reason": "TEST_FAILED"}]
    result = agent.run(failures)
    assert result["status"] == "success"
    patterns = load_patterns(tmp_path / "pattern_db.yaml")
    assert "TEST_FAILED" in patterns.get("known_reasons", [])


def test_scheduler_runs_tasks():
    scheduler = Scheduler()
    scheduler.register("task1", lambda: {"status": "success"})
    results = scheduler.run_all()
    assert results and results[0]["task"] == "task1"


def test_pattern_learner_round_trip(tmp_path):
    path = tmp_path / "db.yaml"
    patterns = load_patterns(path)
    assert patterns["known_reasons"] == []
    update_patterns(path, patterns, [{"reason": "LINT_FAILED"}])
    patterns = load_patterns(path)
    assert "LINT_FAILED" in patterns["known_reasons"]
