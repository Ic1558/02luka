# Feature: Work-Order Timeline / History View

**Date:** 2025-11-15  
**Scope:** Dashboard-only, read-only

## Goals

- Provide a **unified, chronological view** of all WO executions.
- Reuse existing WO state collector logic.
- Keep changes **isolated to the dashboard**:
  - No CI changes
  - No security contract changes
  - No orchestrator changes

## API Design

### `GET /api/wos/history`

Query parameters:

- `status` (optional) — filter by status (`success|failed|running|queued`)
- `agent` (optional) — filter by agent/runner
- `type` (optional) — filter by WO type
- `limit` (optional) — max items (default 200)
- `tail=1` (optional) — include log tail (20 lines) when available

Response:

```jsonc
{
  "items": [
    {
      "id": "WO-20251115-001",
      "status": "success",
      "type": "fix",
      "agent": "CLC",
      "started_at": "2025-11-15T05:23:00+07:00",
      "finished_at": "2025-11-15T05:24:10+07:00",
      "duration_sec": 70.0,
      "summary": "sandbox guardrails applied",
      "log_tail": ["...", "..."],
      "related_pr": "PR-280",
      "tags": ["codex", "sandbox", "security"]
    }
  ],
  "summary": {
    "total": 1,
    "status_counts": {
      "success": 1,
      "failed": 0,
      "running": 0,
      "queued": 0
    }
  }
}
```

## UI Design

- New nav button: **"WO Timeline"**
- New view: `#wo-timeline-view`
  - Filters: status, agent, limit
  - Summary bar: total + counts per status
  - List of cards:
    - ID + status + type + agent
    - Started / Finished / Duration
    - Summary / tags / related PR
    - Optional log tail (collapsible)

## Non-Goals (this PR)

- No MLS integration yet (future step: overlay MLS entries onto timeline).
- No write paths to WO state.
- No alerting or auto-recovery logic.

## Future Work

- v2: show MLS markers on the timeline (solutions/failures).
- v3: per-agent timelines (Mary / CLC / Codex).
- v4: WO + CI + telemetry correlation.
