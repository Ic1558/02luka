# WO Timeline / History View — Dashboard Feature (2025-11-15)

## Summary

Adds a **timeline panel** to the Work Orders dashboard so operators can:

- Inspect key lifecycle events for a WO (created, started, finished/completed, last
  updated, optional custom events), and
- See the **log tail** (up to N lines) without leaving the UI.

This is a **front-end only** feature that uses the existing
`GET /api/wos/:id?tail=200` endpoint.

## Files

- `apps/dashboard/index.html`
  - Ensures a **Timeline** column in the WO table.
  - Adds `#wo-timeline-section`:
    - Header:
      - `#wo-timeline-title`
      - `#wo-timeline-subtitle`
      - `#wo-timeline-close` button.
    - Content container: `#wo-timeline-content`.
  - Highlights the selected WO row via `.wo-timeline-active-row` so operators always know which WO is open in the panel.

- `apps/dashboard/dashboard.js`
  - State:
    - `currentTimelineWoId`.
  - Row rendering:
    - Timeline column contains a `Timeline` button that calls
      `openWoTimeline(wo.id)`.
  - Timeline logic:
    - `initWoTimeline()`:
      - Wires the Close button and hide/show behavior.
    - `openWoTimeline(woId)`:
      - Fetches `/api/wos/:id?tail=200`.
      - Updates title, subtitle, and panel visibility.
      - Delegates to `renderWoTimelineContent(wo)`.
      - Keeps the originating row highlighted via `highlightActiveTimelineRow()`.
    - `buildTimelineSubtitle(wo)`:
      - Shows status + important timestamps.
    - `formatWoTime(value)`:
      - Formats timestamps as `YYYY-MM-DD HH:MM`.
    - `renderWoTimelineContent(wo)`:
      - Generates two columns:
        - Events (`.wo-timeline-events`)
        - Log tail (`.wo-timeline-logs`)
    - `buildWoEventsList(wo)`:
      - Builds a sorted list of key events from:
        - `created_at`, `started_at`, `completed_at` (or `finished_at`),
          `updated_at`/`last_update`
        - Optional `wo.events[]`.
    - `getWoCompletedTime(wo)`:
      - Helper function that checks `completed_at` first, then falls back to `finished_at`/`finishedAt`.
      - This addresses the Codex review comment about completed timestamps not being rendered.
    - `highlightActiveTimelineRow()` keeps the WO table button state (`aria-pressed`) and background in sync with the panel, and `initWoTimeline()` now resets the panel text/content when closing.

- `g/reports/system/wo_timeline_feature_20251115.md`
  - This document.

## Behavior

- Clicking **Timeline** in a WO row:
  - Opens the panel.
  - Loads detailed WO info with `tail=200`.
  - Shows lifecycle events on the left, log tail on the right.
  - Highlights the active WO row until the panel is closed.
- Clicking **Close** hides the panel.
  - The panel header resets to the default helper text and the table highlight is cleared.
- If there is no timeline data:
  - Shows a friendly "No timeline events available" message.
- If there is no log tail:
  - Shows "No log tail available for this work order."

## Data Source

- Uses `GET /api/wos/:id?tail=200` provided by `apps/dashboard/api_server.py`.
- Expects:
  - `id`, `status`
  - Optional: `created_at`, `started_at`, `completed_at`, `finished_at`, `updated_at` /
    `last_update`, `worker`, `result`, `last_error`, `log_tail[]`.

## Risk

- API usage:
  - Uses existing `GET /api/wos/:id` with optional `tail` parameter.
  - No new endpoints.
- No changes to:
  - Server code (`api_server.py`, `wo_dashboard_server.js`).
  - Security or signature verification.
  - CI workflows.
- If fields are missing, timeline gracefully degrades.

Risk level: **Low**.
