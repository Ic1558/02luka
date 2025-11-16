# WO Status Filters — Dashboard Feature (2025-11-16)

## Summary

Adds client-side status filters to the Work Orders dashboard:

- Chips for **All**, **Active**, **Pending**, **Running**, **Completed**,
  **Failed**
- Uses existing `GET /api/wos?status=...` support in the API handler
- No changes to security, workflows, or WO state files

This is a **front-end only** feature.

## Files

- `apps/dashboard/index.html`
  - New `#wo-status-filters` container with:
    - data-status="" → All
    - data-status="pending,running" → Active
    - data-status="pending" → Pending
    - data-status="running" → Running
    - data-status="completed" → Completed
    - data-status="failed,error" → Failed
  - Adds chip styling classes:
    - `.wo-status-filters`
    - `.wo-status-chip`
    - `.wo-status-chip--active`

- `apps/dashboard/dashboard.js`
  - New state:
    - `currentWoStatusFilter`
  - New function:
    - `initWoStatusFilters()`:
      - Wires click handlers for `.wo-status-chip`
      - Updates `currentWoStatusFilter`
      - Reloads WOs via `loadWos()`
  - `loadWos()` updated to:
    - Add `status=currentWoStatusFilter` to query string when set.

- `g/reports/system/wo_status_filters_feature_20251116.md`
  - This document.

## Behavior

- Default state:
  - "All" chip is active.
  - `currentWoStatusFilter = ""`
  - `/api/wos` called without `status` param.
- When selecting a chip:
  - That chip becomes active.
  - `currentWoStatusFilter` set to its `data-status` value.
  - `loadWos()` is called.
  - The request includes `?status=pending,running` or similar.
- Backend logic:
  - Uses existing `handle_list_wos` implementation:
    - `status_filter = query.get('status', [''])[0]`
    - If present, splits by comma and filters in-memory.

## Risk

- No changes to:
  - `api_server.py`
  - `wo_dashboard_server.js`
  - Security/verifySignature
  - CI workflows
  - LaunchAgents
- Front-end only; backend interface is already in place.

Risk level: **Low**.
