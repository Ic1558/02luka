"""WO Reality command handler for Kim Telegram bot."""

from __future__ import annotations

import os
from textwrap import dedent
from typing import Any, Dict

import requests

DASHBOARD_BASE = os.getenv("DASHBOARD_BASE_URL", "http://localhost:8080")


def format_reality_insights(data: Dict[str, Any]) -> str:
    """Convert WO insights JSON into a short bilingual message."""

    wo_id = data.get("id", "UNKNOWN")
    status = data.get("status", "unknown")
    agent = data.get("agent") or "-"
    summary = data.get("summary") or "-"
    related_pr = data.get("related_pr") or "-"
    duration = data.get("duration_sec")
    tags = ", ".join(data.get("tags") or [])

    mls = data.get("mls_summary") or {}
    rec = data.get("recommendation") or {}

    duration_text = (
        f"{int(duration)}s" if isinstance(duration, (int, float)) else "-"
    )

    if mls:
        mls_line = (
            f"MLS: total {mls.get('total', 0)}, "
            f"solutions {mls.get('solutions', 0)}, "
            f"failures {mls.get('failures', 0)}, "
            f"patterns {mls.get('patterns', 0)}, "
            f"improvements {mls.get('improvements', 0)}"
        )
    else:
        mls_line = "MLS: (no entries)"

    rec_title = rec.get("title") or "No immediate action"
    rec_details = rec.get("details") or ""
    rec_level = rec.get("level") or "info"
    rec_code = rec.get("code") or "none"

    text = dedent(
        f"""
        🧱 WO Reality Snapshot

        • ID: {wo_id}
        • Status: {status}
        • Agent: {agent}
        • Duration: {duration_text}
        • Summary: {summary}
        • PR: {related_pr or '-'}
        • Tags: {tags or '-'}

        {mls_line}

        📌 Recommendation [{rec_level}/{rec_code}]
        {rec_title}
        {rec_details}

        (source: {DASHBOARD_BASE}/dashboard.html#wo={wo_id})
        """
    ).strip()

    return text


def handle_wo_reality(wo_id: str) -> str:
    """Fetch and render WO insights from the dashboard API."""

    wo_id = (wo_id or "").strip()
    if not wo_id:
        return "❗ Usage: /wo <WO-ID>  เช่น /wo WO-20251115-001"

    url = f"{DASHBOARD_BASE}/api/wos/{wo_id}/insights"
    try:
        resp = requests.get(url, timeout=5)
    except Exception as exc:  # pragma: no cover - network defensive
        return f"❗ ดึงข้อมูล WO ไม่ได้: {exc}"

    if resp.status_code == 404:
        return f"❗ ไม่พบ WO: {wo_id}"
    if resp.status_code != 200:
        body_preview = resp.text[:200]
        return f"❗ Dashboard คืน status {resp.status_code}: {body_preview}"

    try:
        data = resp.json()
    except Exception as exc:  # pragma: no cover - data defensive
        return f"❗ Response ไม่ใช่ JSON ที่อ่านได้: {exc}"

    if not isinstance(data, dict):
        return "❗ Response ไม่ใช่ JSON ที่อ่านได้: expected object"

    return format_reality_insights(data)
