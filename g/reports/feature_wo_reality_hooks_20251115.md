# Feature: WO Reality Hooks (Agent-facing insights)

**Date:** 2025-11-15  
**Scope:** Dashboard + tools, read-only

## Goals

- Provide a stable, machine-friendly snapshot of a WO:
  - status, type, agent, timestamps
  - MLS summary
  - simple rule-based recommendation
- Enable local agents (Mary, CLC, Kim, etc.) to consume these snapshots
  without touching internals of the dashboard code.

## API: GET /api/wos/:id/insights

Response (simplified):

```jsonc
{
  "id": "WO-20251115-001",
  "status": "failed",
  "type": "fix",
  "agent": "CLC",
  "started_at": "...",
  "finished_at": "...",
  "duration_sec": 70.0,
  "summary": "sandbox guardrails applied",
  "related_pr": "PR-280",
  "tags": ["codex", "sandbox"],
  "mls_summary": {
    "total": 3,
    "solutions": 1,
    "failures": 2,
    "patterns": 0,
    "improvements": 0
  },
  "recommendation": {
    "level": "high",
    "code": "mls_failures_no_solution",
    "title": "MLS records failures without solutions",
    "details": "This WO has MLS failure entries but no solution logged. Consider creating or linking a solution lesson."
  }
}
```

Tool: `tools/wo_reality_snapshot.zsh`
- Usage: `tools/wo_reality_snapshot.zsh WO-20251115-001`
- Output: `g/reports/system/reality_hooks/WO-WO-20251115-001.json`
- Config: honors `WO_API_BASE` (defaults to `http://localhost:8767`)
- Purpose: Stable JSON snapshot for agents, CI, and dashboards.

## Non-Goals

This PR does **not**:
- Modify orchestrator or WO execution logic.
- Automatically create MLS entries.
- Add LLM-based reasoning.

## Future Work

- Connect Kim / Telegram / Mary to these snapshots ("Show me reality snapshot for WO X").
- Generate daily reality summary (e.g., how many failed WOs without solutions).
