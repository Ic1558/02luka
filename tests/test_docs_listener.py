from __future__ import annotations

from pathlib import Path

from agents.docs_v4.docs_worker import DocsWorkerV4


def test_docs_worker_listens_and_summarizes(tmp_path, monkeypatch):
    monkeypatch.setenv("LAC_BASE_DIR", str(tmp_path))
    telemetry_dir = tmp_path / "g/telemetry/lac"
    telemetry_dir.mkdir(parents=True, exist_ok=True)
    events_file = telemetry_dir / "events.jsonl"
    conversations_file = tmp_path / "g/telemetry/agent_conversations.jsonl"
    conversations_file.parent.mkdir(parents=True, exist_ok=True)

    events_file.write_text(
        '\n'.join(
            [
                '{"event_type":"DEV_COMPLETED","lane":"dev_oss","status":"success"}',
                '{"event_type":"QA_COMPLETED","lane":"qa_v4","status":"success"}',
            ]
        ),
        encoding="utf-8",
    )
    conversations_file.write_text(
        '\n'.join(
            [
                '{"speaker":"dev_oss","message":"done"}',
                '{"speaker":"qa_v4","message":"pass"}',
            ]
        ),
        encoding="utf-8",
    )

    worker = DocsWorkerV4()
    result = worker.execute_task({"operation": "listen", "summary_path": str(tmp_path / "g/docs/summary.md")})
    assert result["status"] == "success"
    summary_file = Path(tmp_path / "g/docs/summary.md")
    assert summary_file.exists()
    content = summary_file.read_text(encoding="utf-8")
    assert "DEV_COMPLETED" in content
    assert "QA_COMPLETED" in content
    assert "dev_oss" in content
    assert "qa_v4" in content


def test_collect_events_resolves_relative_paths_from_base_dir(tmp_path, monkeypatch):
    """Test that relative paths in collect_events resolve relative to base_dir, not CWD."""
    from agents.docs_v4.listener import collect_events
    import os

    base_dir = tmp_path / "project"
    base_dir.mkdir()

    # Create telemetry file in base_dir with relative path
    custom_telemetry = base_dir / "g" / "telemetry" / "custom.jsonl"
    custom_telemetry.parent.mkdir(parents=True)
    custom_telemetry.write_text('{"event_type":"CUSTOM","lane":"test"}\n', encoding="utf-8")

    # Change to a different directory to verify path resolution
    original_cwd = os.getcwd()
    try:
        os.chdir("/tmp")  # Different directory
        result = collect_events(base_dir, telemetry_path="g/telemetry/custom.jsonl", limit=10)
        # Should find the file even though CWD is /tmp
        assert len(result["events"]) == 1
        assert result["events"][0]["event_type"] == "CUSTOM"
    finally:
        os.chdir(original_cwd)
