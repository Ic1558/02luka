import os
from pathlib import Path

import agents.alter.helpers as alter_helpers
from agents.docs_v4.docs_worker import DocsWorkerV4


def test_docs_worker_polish_applies_when_requested(tmp_path, monkeypatch):
    monkeypatch.setenv("LAC_BASE_DIR", str(tmp_path))

    def fake_polish(content: str, context=None):
        return content.upper()

    # Route both helpers to the same fake polish to avoid external calls.
    monkeypatch.setattr("agents.docs_v4.docs_worker.polish_if_needed", fake_polish)
    monkeypatch.setattr("agents.docs_v4.docs_worker.polish_and_translate_if_needed", fake_polish)

    worker = DocsWorkerV4()
    task = {
        "polish": True,
        "tone": "formal",
        "patches": [
            {"file": "g/docs/sample.md", "content": "hello world"},
        ],
    }

    result = worker.execute_task(task)
    assert result["status"] == "success"

    out_path = Path(tmp_path / "g/docs/sample.md")
    assert out_path.exists()
    assert out_path.read_text() == "HELLO WORLD"
