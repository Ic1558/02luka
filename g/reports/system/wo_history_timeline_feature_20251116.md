# WO History / Timeline View — Dashboard Feature (2025-11-16)

## Summary

Adds a **History** tab to the dashboard that shows a grouped timeline of
work orders:

- Groups WOs by calendar day
- Shows status, title, ID, time range, and duration
- Provides quick summary: totals, success rate, average duration
- Uses the existing `GET /api/wos` endpoint (no backend changes)

This is a **front-end only** feature.

## Files

- `apps/dashboard/index.html`
  - Adds "History" tab button to the Work Orders view switcher.
  - Adds `#view-wo-history` panel containing:
    - Range selector (`#wo-history-range`).
    - Status selector (`#wo-history-status`).
    - Summary container (`#wo-history-summary`).
    - Timeline container (`#wo-history-timeline`).

- `apps/dashboard/dashboard.js`
  - Helpers:
    - `toLocalDateString(ts)`
    - `computeDurationMs(wo)`
    - `formatDuration(ms)`
    - `groupWosByDay(wos)`
  - Rendering:
    - `renderWoHistoryTimeline(wos)`:
      - Computes summary: total, completed, failed, success rate, avg duration
      - Groups WOs by day and renders timeline UI.
  - Loading:
    - `loadWoHistory()`:
      - Reads range + status from DOM
      - Calls `GET /api/wos?status=...`
      - Sorts by start time desc, slices to limit
      - Renders via `renderWoHistoryTimeline()`
  - Init:
    - `initWoHistoryTab()`:
      - Wires change handlers on range + status selectors.
    - Updates tab handler to:
      - Call `loadWoHistory()` on first switch to History tab.

- `g/reports/system/wo_history_timeline_feature_20251116.md`
  - This document.

## Behavior

- Default:
  - History tab is not loaded until first selected (lazy load).
  - Initial filters:
    - Range: last 50 WOs.
    - Status: completed + failed/error (can be adjusted).
- On History tab open:
  - `loadWoHistory()` fetches WOs, applies filters, and renders timeline.
- On filter change:
  - History reloads with new range/status.

## Risk

- No changes to:
  - `apps/dashboard/api_server.py`
  - `apps/dashboard/wo_dashboard_server.js`
  - `server/security/*`
  - CI workflows / LaunchAgents / tools
- Uses existing `/api/wos` interface, only on the client.

Risk level: **Low**.
