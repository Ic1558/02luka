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
    catalog_file = tmp_path / "g/catalog/file_catalog.yaml"
    qa_telemetry = tmp_path / "g/telemetry/qa_checklists.jsonl"

    assert output_file.exists()
    assert summary_file.exists()
    assert catalog_file.exists()
    assert qa_telemetry.exists()

    content = summary_file.read_text(encoding="utf-8")
    assert "Requirement: REQ-20251129-SELF" in content
    assert "Status: success" in content
    assert "QA Status: success" in content

    assert "pipeline_output.txt" in catalog_file.read_text(encoding="utf-8")
    telemetry_lines = qa_telemetry.read_text(encoding="utf-8").strip().splitlines()
    assert telemetry_lines and "checklist" in telemetry_lines[-1]
