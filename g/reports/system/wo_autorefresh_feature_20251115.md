# WO Auto-Refresh & Last-Refresh Indicator — Dashboard Feature (2025-11-15)

## Summary

Adds an **auto-refresh control** and **last-refresh indicator** to the
Work Orders view so operators can treat the dashboard as a live monitor
without manually reloading the page.

This is a **front-end only** change that calls the existing `GET /api/wos`
endpoint at a configurable interval.

## Files

- `apps/dashboard/index.html`
  - Extends the Work Orders header with:
    - `#wo-autorefresh-toggle` checkbox ("Auto-refresh")
    - `#wo-autorefresh-interval` select (10s / 30s / 60s)
    - `#wos-last-refresh` label
    - `#wo-refresh-now` button ("Refresh now")

- `apps/dashboard/dashboard.js`
  - Adds state:
    - `woAutorefreshTimer`
    - `woAutorefreshEnabled`
    - `woAutorefreshIntervalMs`
    - `woRefreshAbortController`
    - `woRefreshRequestId`
  - Adds functions:
    - `refreshWos()` → fetches `/api/wos`, updates `allWos` and calls
      `applyWoFilter()`, updates `#wos-last-refresh`.
    - `updateWoLastRefreshLabel(success)` → sets the timestamp label.
    - `initWoAutorefreshControls()` → wires toggle, interval, and "Refresh now".
    - `startWoAutorefresh()`, `stopWoAutorefresh()`,
      `restartWoAutorefreshIfNeeded()` → manage polling timer.
  - Keeps `loadWos()` as a wrapper around `refreshWos()` for backward
    compatibility.

- `g/reports/system/wo_autorefresh_feature_20251115.md`
  - This document.

## Behavior

- When **Auto-refresh** is enabled:
  - `refreshWos()` is called every N milliseconds as configured by the
    interval select (default 30s).
- `refreshWos()` cancels any prior in-flight fetch so only the latest
  response updates the UI and timestamp label.
- The **Last refresh** label displays:
  - `Last refresh: HH:MM:SS` on success.
  - `Last refresh: error at HH:MM:SS` if the fetch fails.
- The **Refresh now** button triggers a one-off `refreshWos()` call.

## Risk

- No changes to:
  - APIs
  - Security or signing
  - CI workflows or telemetry

- If the endpoint is slow or temporarily failing:
  - The label shows an error message.
  - Auto-refresh continues; failures are logged to console.

Risk level: **Low**.
