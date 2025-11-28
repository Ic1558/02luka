from __future__ import annotations

import os
from textwrap import dedent

import pytest

from agents.ai_manager.ai_manager import AIManager


@pytest.mark.slow
def test_self_complete_pipeline_runs_end_to_end(tmp_path, monkeypatch):
    monkeypatch.setenv("LAC_BASE_DIR", str(tmp_path))
    monkeypatch.setenv("LAC_COMPLETIONS_LOG", str(tmp_path / "completions.jsonl"))

    requirement_md = dedent(
        """
        # Requirement: Hello World
        **ID:** REQ-20251129-SELF
        **Priority:** P2
        **Complexity:** Simple

        ## Objective
        Write a hello world file.

        ## Acceptance Criteria
        - [ ] A file is created
        """
    ).strip()

    manager = AIManager()
    result = manager.run_self_complete(requirement_md)

    assert result["status"] == "success"
    output_file = tmp_path / "g/src/pipeline_output.txt"
    summary_file = tmp_path / "g/docs/pipeline_summary.md"
    assert output_file.exists()
    assert summary_file.exists()
    assert "Pipeline completed" in summary_file.read_text(encoding="utf-8")
