# WO Status Filters & Chips — Dashboard Feature (2025-11-15)

## Summary

Adds **status filters** and compact **status chips** to the Work Orders list:

- Filter bar:
  - All, Pending, Running, Completed, Failed
- Summary line:
  - e.g. "12 WOs · 3 running · 1 failed · filter: running (3 shown)"
- Status chips:
  - Color-coded labels in the Status column

This is a **pure front-end feature** that uses the existing `GET /api/wos`
endpoint; no server-side logic or workflows are changed.

## Files

- `apps/dashboard/index.html`
  - Adds filter bar with `.wo-filter-button` buttons and `data-status` keys.
  - Adds summary element `#wos-summary`.

- `apps/dashboard/dashboard.js`
  - Tracks:
    - `allWos`, `visibleWos`, `currentWoFilter`.
  - Adds:
    - `initWoFilters()` → wires up filter buttons.
    - `setWoFilter(statusKey)` → activates a filter and updates button styles.
    - `applyWoFilter()` → computes `visibleWos` and re-renders.
    - `normalizeWoStatus(raw)` → maps various status strings into:
      - `pending`, `running`, `completed`, `failed`, `other`.
    - `renderWoSummary(wos)` → shows aggregate counts in `#wos-summary`.
  - Enhances `renderWosTable()` to render a status chip per row.

- `g/reports/system/wo_filters_feature_20251115.md`
  - This document.

## Behavior

- `GET /api/wos` remains unchanged.
- Filtering is **client-side only**, based on `wo.status`.
- The summary line counts status buckets across all WOs, not just filtered ones.

## Risk

- No CI workflows modified.
- No auth, signing, or filesystem behavior modified.
- If a WO has an unknown status string, it goes into the `other` bucket and
  still renders as a neutral chip.

Risk level: **Low**.
