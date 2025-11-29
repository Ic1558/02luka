from __future__ import annotations

from agents.dev_oss.dev_worker import DevOSSWorker


def test_dev_prompt_includes_pattern_warnings():
    worker = DevOSSWorker(backend=None)
    prompt = worker._build_prompt(
        {
            "wo_id": "WO-TEST",
            "objective": "Test objective",
            "routing_hint": "dev_oss",
            "priority": "P2",
            "content": "Do something",
            "architect_spec": {"pattern_warnings": ["TEST_FAILED"]},
        }
    )
    assert "PatternWarnings:" in prompt
    assert "TEST_FAILED" in prompt
