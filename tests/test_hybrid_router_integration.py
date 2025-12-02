import os
from pathlib import Path

import agents.ai_manager.hybrid_router as hr
from agents.docs_v4.docs_worker import DocsWorkerV4


def test_high_sensitivity_routes_to_local(monkeypatch):
    monkeypatch.setattr(hr, "_call_local", lambda text, ctx: f"LOCAL:{text}")
    monkeypatch.setattr(hr, "_call_gg", lambda text, ctx: f"GG:{text}")

    text, meta = hr.hybrid_route_text("Test text", {"sensitivity": "high"})
    assert meta["engine_used"] == hr.ENGINE_LOCAL
    assert text.startswith("LOCAL:")
    assert meta["fallback"] is False


def test_client_facing_routes_to_alter(monkeypatch):
    monkeypatch.setattr(hr, "_call_gg", lambda text, ctx: "draft")

    def fake_alter(text, ctx):
        return "polished", {"alter_status": "used", "quota_daily_remaining": 199, "quota_lifetime_remaining": 39999}

    monkeypatch.setattr(hr, "_call_alter_polish", fake_alter)

    text, meta = hr.hybrid_route_text("Draft text", {"client_facing": True, "mode": "polish", "project_id": "PD17"})
    assert meta["engine_used"] == hr.ENGINE_ALTER
    assert text == "polished"
    assert meta["alter_status"] == "used"


def test_docs_worker_integration(monkeypatch, tmp_path):
    monkeypatch.setenv("LAC_BASE_DIR", str(tmp_path))

    def fake_hybrid_route(text, context):
        return "POLISHED_DOC", {"engine_used": hr.ENGINE_ALTER, "alter_status": "used", "fallback": False}

    monkeypatch.setattr("agents.docs_v4.docs_worker.hybrid_route_text", fake_hybrid_route)

    # Avoid file writes in test by stubbing save gateway
    def fake_save(self, content, agent_id, source, project_id, topic):
        out = Path(tmp_path / "g/docs/output.md")
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(content, encoding="utf-8")

    monkeypatch.setattr(DocsWorkerV4, "_save_via_gateway", fake_save)

    worker = DocsWorkerV4()
    task = {
        "project_id": "PD17",
        "topic": "client_report",
        "title": "Test Report",
        "client_facing": True,
        "mode": "polish",
        "summary": "Key updates for client.",
    }

    result = worker.generate_client_report_with_hybrid_router(task)
    assert result["ok"] is True
    assert result["engine_used"] == hr.ENGINE_ALTER
    assert result["alter_status"] == "used"
