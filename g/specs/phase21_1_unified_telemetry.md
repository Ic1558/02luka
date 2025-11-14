# Phase 21.1 — Unified Telemetry API (Minimal Kickoff)
- Scope: รวม event format เดียว, output ลง `g/telemetry/unified.jsonl`
- Contract (JSON Lines):
  {
    "ts": "<ISO8601 UTC>",
    "agent": "<module>",
    "event": "<name>",
    "ok": true|false,
    "detail": { "file": "...", "sha256": "...", "note": "..." }
  }
- v0: เพิ่มจุดยิงใน OCR (sha256_validation) และเตรียม util logger ที่เรียกด้วย `tools/telemetry_unified.zsh log ...`
- ไม่แก้ CI / dispatch / workflows
