from __future__ import annotations

from pathlib import Path

from agents.docs_v4.docs_worker import DocsWorkerV4


def test_docs_summary_includes_pattern_warnings(tmp_path, monkeypatch):
    base_dir = tmp_path
    monkeypatch.setenv("LAC_BASE_DIR", str(base_dir))

    worker = DocsWorkerV4()
    result = worker.execute_task(
        {
            "operation": "summary",
            "requirement_id": "REQ-TEST",
            "status": "success",
            "lane": "dev_oss",
            "qa_status": "success",
            "files_touched": [],
            "pattern_warnings": ["TEST_FAILED"],
            "summary_path": str(base_dir / "g/docs/pipeline_summary.md"),
        }
    )

    assert result["status"] == "success"
    summary_file = Path(base_dir / "g/docs/pipeline_summary.md")
    assert summary_file.exists()
    content = summary_file.read_text(encoding="utf-8")
    assert "Pattern Warnings" in content
    assert "TEST_FAILED" in content
