# Feature: Work Order Timeline / History View (Dashboard 2.1)

## Overview

This feature delivers a dedicated Work Order Timeline / History view for the 02luka dashboard. It combines all existing WO telemetry
sources into a single chronological feed, unlocks inline log inspection, and surfaces MLS context to help diagnose failures without
leaving the dashboard.

The implementation is intentionally **read-only** and uses only the artifacts that already exist on disk:

- `followup/state/*.json` – canonical WO state snapshots
- `g/apps/dashboard/data/followup.json` (fallback) – curated follow-up tracker entries
- `logs/wo_execution_*` – execution logs for inline tails
- `g/knowledge/mls_lessons.jsonl` – MLS ledger for failure tags/context

## Backend additions

### `/api/wos/history`

New read-only endpoint implemented in `g/apps/dashboard/api_server.py`.

- Uses the hardened `WOHistoryBuilder` normalization layer.
- Aggregates WO data from state files, follow-up JSON, and the existing `WOCollector` snapshot.
- Hydrates MLS context (lessons + tags) and inline log tails (default 50 lines, adjustable via `tail` query param).
- Supports lightweight filters and pagination controls:
  - `status=queued,running,success,failed,dropped,timeout`
  - `agent=CLC,MLS`
  - `type=fix,analysis,...`
  - `limit=200` (default)
  - `tail=50` (min 5 / max 500)
- Returns a normalized object per WO:

```json
{
  "id": "WO-20251115-001",
  "status": "success",
  "agent": "CLC",
  "type": "fix",
  "summary": "sandbox fix applied",
  "started_at": "2025-11-15T03:21:00Z",
  "finished_at": "2025-11-15T03:25:44Z",
  "duration_seconds": 284.0,
  "timeline_segments": [
    { "label": "Started", "value": "2025-11-15T03:21:00Z" },
    { "label": "Finished", "value": "2025-11-15T03:25:44Z" },
    { "label": "Duration", "value": "284s" }
  ],
  "log_tail": ["... last 50 lines ..."],
  "mls_tags": ["safety", "rollback"],
  "mls_lessons": [{ "id": "MLS-123", "type": "failure", "title": "Sandbox drift" }],
  "sources": ["state", "followup", "collector"]
}
```

The endpoint never mutates files, never touches orchestrator processes, and reuses the current `WOCollector` cache for zero-risk
reads.

## Frontend additions

### `timeline.html`

A new Tailwind + HTMX powered page (no build tooling required) renders the timeline feed:

- Filters (status, agent, type, log tail window)
- Live reload button using HTMX trigger events
- Card-based layout with:
  - Status indicators + agent/type metadata
  - Timeline chips for started / finished / duration
  - Inline log tail (50 lines by default)
  - MLS tags & lesson summaries when available
  - Quick link back to the main dashboard detail drawer
- Accessible empty/error states and `aria-live` updates for the feed container

### `timeline.js`

Small module responsible for:

- Coordinating filter state + HTMX requests to `/api/wos/history`
- Rendering timeline cards (string templates + HTML escaping)
- Handling loading / error indicators

## Documentation

This document plus the inline comments in `api_server.py`, `timeline.html`, and `timeline.js` describe the full feature surface.

## Future enhancements (v2)

1. **Advanced filtering & grouping**
   - Group by agent or tag, add date-range picker.
2. **Live streaming**
   - Promote `/api/wos/{id}/tail` SSE stream when available for near-real-time updates.
3. **MLS deep links**
   - Link MLS chips directly to ledger entries for fast follow-up.
4. **WO replay hooks**
   - Add retry/cancel buttons once the action endpoints are promoted to production.
5. **Timeline density view**
   - Condensed mini-map of throughput per hour/day for long-running sessions.
