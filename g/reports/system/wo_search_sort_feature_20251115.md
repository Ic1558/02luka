# WO Search & Column Sorting — Dashboard Feature (2025-11-15)

## Summary

Enhances the Work Orders view with:

- A **search box** that filters WOs by ID, title, tags, or context.
- **Click-to-sort** column headers for:
  - ID
  - Status
  - Started
  - Finished
  - Last Update

This is a **front-end only** feature that uses the existing `GET /api/wos`
endpoint and does not change any server logic or workflows.

## Files

- `apps/dashboard/index.html`
  - Work Orders header:
    - Adds `.wos-search-row` with:
      - `#wo-search-input`
      - hint text.
  - Table header:
    - Adds `data-sort-key` attributes on sortable `<th>`:
      - `id`, `status`, `started_at`, `finished_at`, `updated_at`.

- `apps/dashboard/dashboard.js`
  - New state:
    - `currentWoSearch`
    - `currentWoSortKey`
    - `currentWoSortDir`
  - New init:
    - `initWoSearch()` → wires live search on `#wo-search-input` and keeps the input synced with state.
    - `initWoSorting()` → attaches click handlers to `th[data-sort-key]`.
    - `updateWoSortHeaderStyles()` → adds `sort-asc` / `sort-desc` classes.
  - Enhancements:
    - `applyWoFilter()` now:
      1. Filters by status.
      2. Filters by search text through a shared `buildWoSearchHaystack()` helper.
      3. Sorts via `compareWos()`.
    - `compareWos(a, b, sortKey, sortDir)` handles:
      - Numeric-friendly `id` comparisons.
      - Status priority ordering via `WO_STATUS_SORT_ORDER`.
      - Timestamp-based keys `started_at`, `finished_at`, `updated_at`.
    - `normalizeWoTimestamp(value)` for timestamps.
    - `buildWoSearchHaystack(wo)` for consolidated search text.

- `g/reports/system/wo_search_sort_feature_20251115.md`
  - This document.

## Behavior

- **Search**:
  - Case-insensitive.
  - Matches against:
    - `id`
    - `title`
    - `context`
    - `summary` / `description`
    - `agent` / `worker`
    - `type`
    - `action(s)`
    - `tags[]`
    - any contextual metadata string fields
  - Combines with status filters (AND logic).

- **Sorting**:
  - Click a header to sort by that column.
  - Click again to toggle ascending/descending.
  - Default sort: `started_at desc` (newest first).
  - Status sort uses a priority map (`running` → `pending` → `completed` → `failed` → `unknown`).
  - ID sort extracts numeric components so `WO-2` sorts before `WO-10`.

## Risk

- No changes to:
  - Server endpoints.
  - Security / signing.
  - CI workflows.

- If some fields are missing or malformed:
  - Timestamps fall back to 0 and appear at one end of the list.

Risk level: **Low**.
