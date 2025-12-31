import json
from pathlib import Path

import yaml

import agents.mary_router.gateway_v3_router as gw


def make_config(tmp_path: Path, *, phase1_enabled: bool = True, max_retries: int = 1) -> Path:
    config = {
        "version": "3.0",
        "phase": 1,
        "routing": {
            "default_target": "CLC",
            "supported_targets": ["CLC"],
            "routing_hint_mapping": {},
        },
        "telemetry": {
            "log_file": str(tmp_path / "telemetry.jsonl"),
            "log_level": "INFO",
        },
        "directories": {
            "inbox": "inbox",
            "processed": "processed",
            "error": "error",
        },
        "worker": {
            "sleep_interval_seconds": 0.0,
            "process_one_by_one": True,
        },
        "use_v5_stack": False,
        "phase1": {
            "enabled": phase1_enabled,
            "priority_enabled": True,
            "max_retries": max_retries,
            "retry_backoff_seconds": 0.0,
            "idempotency_enabled": True,
            "idempotency_log": str(tmp_path / "idempotency.log"),
        },
    }
    cfg_path = tmp_path / "config.yaml"
    cfg_path.write_text(yaml.safe_dump(config))
    return cfg_path


def test_priority_sorting(tmp_path, monkeypatch):
    monkeypatch.setattr(gw, "ROOT", tmp_path)
    cfg = make_config(tmp_path, max_retries=1)
    router = gw.GatewayV3Router(cfg)
    router.inbox.mkdir(parents=True, exist_ok=True)
    (router.inbox / "wo_low.yaml").write_text(yaml.safe_dump({"wo_id": "LOW", "priority": 1}))
    (router.inbox / "wo_high.yaml").write_text(yaml.safe_dump({"wo_id": "HIGH", "priority": 5}))
    files = router.list_inbox_files()
    assert files[0].name == "wo_high.yaml"


def test_retry_moves_to_error_when_exhausted(tmp_path, monkeypatch):
    monkeypatch.setattr(gw, "ROOT", tmp_path)
    cfg = make_config(tmp_path, max_retries=1)
    router = gw.GatewayV3Router(cfg)
    router.inbox.mkdir(parents=True, exist_ok=True)
    router.error.mkdir(parents=True, exist_ok=True)
    wo = router.inbox / "wo_fail.yaml"
    wo.write_text(yaml.safe_dump({"wo_id": "FAIL"}))
    router.process_wo = lambda path: False  # force failure
    result = router.process_next()
    assert result is False
    assert not wo.exists()
    assert (router.error / "wo_fail.yaml").exists()


def test_idempotency_skip(tmp_path, monkeypatch):
    monkeypatch.setattr(gw, "ROOT", tmp_path)
    cfg = make_config(tmp_path, max_retries=1)
    router = gw.GatewayV3Router(cfg)
    router.inbox.mkdir(parents=True, exist_ok=True)
    router.processed.mkdir(parents=True, exist_ok=True)
    router.record_idempotent("WO-DUP", "ok")
    wo = router.inbox / "wo_dup.yaml"
    wo.write_text(yaml.safe_dump({"wo_id": "WO-DUP"}))
    ok = router.process_wo(wo)
    assert ok is True
    assert not wo.exists()
    assert (router.processed / "wo_dup.yaml").exists()
