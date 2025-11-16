# Reality Advisory Badges — Dashboard Integration (2025-11-15)

## Summary

Adds **advisory badges** to the dashboard's Reality tab, surfacing the latest
Reality Hooks advisory status for:

- Deployment
- `save.sh` full-cycle tests
- Orchestrator summary

The badges are read-only indicators and do not change any CI or signing
behavior. They are derived from the latest
`g/reports/system/reality_hooks_advisory_latest.md` report.

## Files

- `g/apps/dashboard/api_server.py`
  - Extends `GET /api/reality/snapshot`:
    - Accepts `?advisory=1` to include an `advisory` field:
      ```jsonc
      {
        "advisory": {
          "deployment": { "status": "ok|no_data|degraded|unknown" },
          "save_sh": { "status": "ok|degraded|no_data|no_snapshot|unknown" },
          "orchestrator": { "status": "ok|no_data|unknown" }
        }
      }
      ```
    - Advisory is read from `g/reports/system/reality_hooks_advisory_latest.md`
      if present; otherwise defaults to `"unknown"`.
    - Snapshot + advisory lookups now target `g/reports/system/` (the
      aggregator output directory) so the API can always find the newest
      Reality Hooks artifacts.

- `apps/dashboard/index.html`
  - Adds badges to Reality header:
    - `#reality-badge-deploy`
    - `#reality-badge-save`
    - `#reality-badge-orch`
  - Optional CSS for badge colors.

- `apps/dashboard/dashboard.js`
  - `loadRealitySnapshot()` now calls `/api/reality/snapshot?advisory=1`.
  - `renderRealitySnapshot()`:
    - Renders snapshot as before.
    - Uses `payload.advisory` (if present) to update badges via
      `updateRealityBadge()` helper.

## Behavior

- If advisory report exists:
  - Badges show `Deployment: ok|no_data|degraded|unknown`, etc.
- If advisory report is missing:
  - Badges show neutral labels (`Deployment`, `save.sh`, `Orchestrator`).
- If snapshot is missing or invalid:
  - Meta message indicates the situation.
  - Badges still reflect advisory status if available.

## Risk

- Backend change is additive and read-only.
- No CI workflows modified.
- If advisory parsing fails, it logs and falls back to `"unknown"`.

Risk level: **Low**.
