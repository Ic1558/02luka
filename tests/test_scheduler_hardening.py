from __future__ import annotations

import json
from pathlib import Path

import pytest

from g.maintenance import catalog_rebuild, scheduler_entrypoint


def test_scheduler_entrypoint_logs_failure(tmp_path, monkeypatch):
    base_dir = tmp_path / "lac_base"
    base_dir.mkdir(parents=True, exist_ok=True)
    (base_dir / "g/telemetry").mkdir(parents=True, exist_ok=True)

    monkeypatch.setenv("LAC_BASE_DIR", str(base_dir))

    # Force a task failure
    def boom():
        raise RuntimeError("boom")

    monkeypatch.setattr(catalog_rebuild, "run", boom)

    scheduler_entrypoint.main()

    log_path = base_dir / "g/telemetry/background_tasks.jsonl"
    assert log_path.exists()
    lines = log_path.read_text(encoding="utf-8").strip().splitlines()
    assert lines
    records = [json.loads(line) for line in lines]
    assert any(r.get("task") == "catalog_rebuild" and r.get("status") == "error" for r in records)
