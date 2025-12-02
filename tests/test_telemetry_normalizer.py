import json
from pathlib import Path

from g.tools.telemetry_normalizer import normalize_file


def _write_jsonl(path: Path, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        for row in rows:
            handle.write(json.dumps(row) + "\n")


def test_normalize_file(tmp_path):
    src = tmp_path / "g/telemetry/dev_lane_execution.jsonl"
    dest = tmp_path / "g/telemetry/normalized/dev_lane_execution.jsonl"
    rows = [
        {"ts": "2025-11-29T00:00:00Z", "lane": "dev_oss", "status": "success", "reason": "ok"},
        {"timestamp": "2025-11-29T01:00:00Z", "routing_hint": "dev_gmxcli", "status": "failed", "reason": "LINT_FAILED"},
    ]
    _write_jsonl(src, rows)

    result = normalize_file(src, dest, "dev_worker")
    assert result["status"] == "success"
    assert result["count"] == 2
    assert dest.exists()

    out_rows = [json.loads(line) for line in dest.read_text(encoding="utf-8").splitlines()]
    assert out_rows[0]["event"] == "success"
    assert out_rows[1]["event"] == "fail"
    assert out_rows[1]["lane"] == "dev_gmxcli"
    assert out_rows[1]["reason"] == "LINT_FAILED"
