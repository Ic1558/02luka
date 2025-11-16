# Global WO History View — Dashboard Feature (2025-11-15)

## Summary

Adds a read-only **global Work Order History view** to the dashboard, built on
 top of the existing `/api/wos` endpoint.

The view shows recent WOs in a tabular form with:
- Status filter
- Row limit selector
- Sorting by newest first

No changes are made to server-side auth, signature verification, or WO write
paths.

## Files

- `apps/dashboard/index.html`
  - Adds `tab-wo-history` button.
  - Adds `view-wo-history` section with filters + table.

- `apps/dashboard/dashboard.js`
  - Adds:
    - `loadWoHistory()`
    - `renderWoHistory(wos, limit)`
    - `initWoHistoryFilters()`
  - Integrates `tab-wo-history` into the existing tab system.

## Behavior

- Uses `GET /api/wos?status=<optional>` to fetch WOs.
- Sorts by `started_at` (fallback: `id`) descending.
- Limits results client-side (default: 100 rows).
- Escapes all text for display.

## Risk

- **Runtime:** Read-only, no new endpoints.
- **Security:** No new signing surface or file access.
- **CI:** No workflows changed.

Risk level: **Low**.

## Checklist

- [ ] `WO History` tab appears in the dashboard UI.
- [ ] Clicking it shows a table of recent WOs.
- [ ] Status filter works.
- [ ] Limit selector works.
- [ ] No errors in browser console when switching tabs or loading history.
