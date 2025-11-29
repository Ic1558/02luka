from __future__ import annotations

import json
from datetime import datetime
from pathlib import Path

from agents.docs_v4.docs_worker import DocsWorkerV4


def _write_jsonl(path: Path, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        for row in rows:
            f.write(json.dumps(row) + "\n")


def test_docs_background_summary(tmp_path, monkeypatch):
    base_dir = tmp_path
    telemetry_dir = base_dir / "g" / "telemetry"
    telemetry_dir.mkdir(parents=True, exist_ok=True)

    now_iso = datetime.utcnow().isoformat() + "Z"

    _write_jsonl(
        telemetry_dir / "background_tasks.jsonl",
        [
            {"task": "catalog_rebuild", "status": "success", "timestamp": now_iso, "duration_ms": 1200},
            {"task": "health_check", "status": "success", "timestamp": now_iso, "duration_ms": 100},
        ],
    )

    _write_jsonl(
        telemetry_dir / "rnd_analysis.jsonl",
        [
            {"timestamp": now_iso, "patterns_updated": ["FP-001"]},
        ],
    )

    worker = DocsWorkerV4()
    result = worker.execute_task(
        {
            "operation": "background_summary",
            "base_dir": str(base_dir),
            "time_window_hours": 24,
        }
    )

    assert result["status"] == "success"
    summary_rel = Path(result["summary_path"])
    out_path = base_dir / summary_rel
    assert out_path.exists()

    text = out_path.read_text(encoding="utf-8")
    assert "Background task runs" in text
    assert "R&D analyses" in text
    assert "catalog_rebuild" in text
