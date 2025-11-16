# WO Timeline / History View — Dashboard Integration (2025-11-15)

## Summary

Adds a **WO Timeline / History view** to the dashboard. Each work order in the
list now has a "Timeline" button that opens a modal with:

- Basic metadata (ID, status, started / finished / last update times)
- A simple event timeline derived from WO fields
- A raw log tail (read from existing `log_tail` data)

This is a **read-only dashboard feature** that consumes the existing
`GET /api/wos/:id?tail=200` API. No server-side signing, auth, or filesystem
behavior is changed.

## Files

- `apps/dashboard/index.html`
  - Adds "Timeline" column to WO list.
  - Adds `#wo-timeline-modal` modal:
    - `#wo-timeline-title`
    - `#wo-timeline-meta`
    - `#wo-timeline-events`
    - `#wo-timeline-log-tail`
  - Minimal CSS for modal + timeline list.

- `apps/dashboard/dashboard.js`
  - Adds:
    - `openWoTimeline(woId)` → fetches `/api/wos/:id?tail=200` and opens modal.
    - `closeWoTimeline()` → hides the modal.
    - `renderWoTimeline(wo)` → renders metadata, events, log tail.
    - `buildTimelineEventsFromWo(wo, logLines)` → derives event list.
  - Extends WO list rendering to include a "Timeline" button per row.

- `g/reports/system/wo_timeline_feature_20251115.md`
  - This document.

## Behavior

- **Data source:**
  - Uses `GET /api/wos/:id?tail=200` provided by `apps/dashboard/api_server.py`.
  - Expects:
    - `id`, `status`
    - Optional: `created_at`, `started_at`, `finished_at`, `updated_at` /
      `last_update`, `worker`, `result`, `last_error`, `log_tail[]`.

- **Timeline construction:**
  - Base events:
    - `Created` (from `created_at`)
    - `Started` (from `started_at`)
    - `Finished` (from `finished_at`, marked error if status=`failed`)
    - Fallback: `Status: …` if not finished.
  - Optional log events:
    - Last ~5 lines from `log_tail`, marked `error` if line contains "error".

- **UI:**
  - Timeline is shown in an overlay modal, independent of the main table.
  - Raw log tail is collapsed under `<details>`.

## Risk

- No CI workflows modified.
- No security or signing logic modified.
- If fields are missing, timeline gracefully degrades.

Risk level: **Low**.
