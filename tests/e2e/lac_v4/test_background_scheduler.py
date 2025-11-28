from __future__ import annotations

import json
from pathlib import Path

from g.maintenance import scheduler_entrypoint


def test_background_scheduler_smoke(tmp_path, monkeypatch):
    base_dir = tmp_path / "lac_base"
    base_dir.mkdir(parents=True, exist_ok=True)
    (base_dir / "g/telemetry").mkdir(parents=True, exist_ok=True)

    monkeypatch.setenv("LAC_BASE_DIR", str(base_dir))

    qa_telemetry_path = base_dir / "g/telemetry/qa_checklists.jsonl"
    qa_telemetry_path.write_text(
        json.dumps({"status": "fail", "requirement_id": "REQ-TEST", "checks": []}) + "\n", encoding="utf-8"
    )

    scheduler_entrypoint.main()

    background_log = base_dir / "g/telemetry/background_tasks.jsonl"
    rnd_analysis = base_dir / "g/telemetry/rnd_analysis.jsonl"

    assert background_log.exists() and background_log.stat().st_size > 0
    assert rnd_analysis.exists() and rnd_analysis.stat().st_size > 0
