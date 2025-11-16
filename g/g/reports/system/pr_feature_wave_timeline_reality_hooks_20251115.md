# Feature Wave — WO Timeline + Reality Hooks (2025-11-15)

This document indexes the feature wave around **WO observability** and **PR reality checks** so that
no part of the set silently goes missing.

## Scope of this wave

This wave consists of three tightly related PRs:

1. **WO Timeline (Dashboard) — PR_FEAT**
   - Adds a read-only timeline view for each Work Order.
   - Backend:
     - Extends `apps/dashboard/api_server.py`:
       - `handle_get_wo` supports `tail=...` and `timeline=1` query params.
       - `_build_wo_timeline(wo)` derives a `timeline` array from timestamps and `log_tail`.
   - Frontend:
     - Adds a `Timeline` section to the WO detail view in `apps/dashboard/index.html`.
     - Updates `apps/dashboard/dashboard.js`:
       - `loadWoDetail(woId)` requests `GET /api/wos/:id?tail=200&timeline=1`.
       - `renderWoTimeline(events)` renders the derived timeline.
   - Risk level: **Low** (read-only derived data, no new write paths).

2. **Reality Hooks CI — PR_FEAT**
   - Adds `tools/reality_hooks/pr_reality_check.zsh`:
     - `dashboard_smoke`: Node parse of `apps/dashboard/wo_dashboard_server.js` (best-effort).
     - `orchestrator_smoke`: runs `tools/claude_subagents/orchestrator.zsh --summary` and validates
       `g/reports/system/claude_orchestrator_summary.json`.
     - `telemetry_schema`: checks that the first record in
       `g/telemetry_unified/unified.jsonl` satisfies required keys in
       `g/schemas/telemetry_v2.schema.json`.
   - Adds `.github/workflows/reality_hooks.yml`:
     - Runs on PRs to `main`.
     - Executes the reality hooks script and uploads `reality_hooks_pr_<sha>.md` as an artifact.
   - Risk level: **Low** (read-only, CI-only).

3. **Workflow Lint Guard (this PR) — PR_CHORE**
   - Adds `.github/workflows/workflow_lint.yml`:
     - Uses `actionlint` to check **all** `.github/workflows/*.yml` files on push/PR.
   - Purpose:
     - Ensure no new workflow is syntactically broken.
     - Provide a safety net for the Reality Hooks and existing CI workflows.

## Relationship to existing PRs

- **Dashboard hardening / security PRs (#280, #283, #286)**  
  This feature wave is **strictly additive**:
  - WO Timeline uses the current `handle_get_wo` contract and does not change any
    auth or signature logic.
  - Reality Hooks reads orchestrator output and telemetry data but does not alter
    signing, WO state writes, or CI path guards.
  - Workflow Lint only parses workflow YAML; it does not change CI behavior.

- **Governance contract PR (#287)**
  - Reality Hooks + WO Timeline both align with the multi-agent governance contract
    by:
    - Providing better observability for WOs (Timeline).
    - Feeding concrete “reality signals” into PR evaluation (Reality Hooks).

## Sanity checklist for this wave

- [ ] WO Timeline PR merged:
  - [ ] `apps/dashboard/api_server.py` includes `_build_wo_timeline`.
  - [ ] `apps/dashboard/dashboard.js` requests `timeline=1`.
  - [ ] Timeline section visible in WO detail UI.
- [ ] Reality Hooks PR merged:
  - [ ] `tools/reality_hooks/pr_reality_check.zsh` executable.
  - [ ] `Reality Hooks` GitHub workflow present and passing.
  - [ ] `g/reports/system/reality_hooks_pr_<sha>.md` generated for at least one PR.
- [ ] Workflow Lint PR merged:
  - [ ] `Workflow Lint` workflow appears under Actions.
  - [ ] New/edited workflows fail fast if YAML is invalid.

## Notes

This file exists as a **single point of truth** for this wave so that:
- No PR in the set is silently dropped.
- Operators can quickly verify that WO Timeline + Reality Hooks + Workflow Lint are all present.
- Future waves (e.g. global WO history tab, save.sh full-cycle tests) can reference this wave
  as the baseline for observability and reality checks.
