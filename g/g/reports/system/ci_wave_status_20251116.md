# CI / Safety Wave Status — 2025-11-16

## Summary

This document tracks the **post-Codex safety / CI wave** and provides a
single reference for:

- Which PRs were merged
- Which areas they touched (dashboard, orchestrator, CI, governance)
- Where the corresponding system reports live
- How to run a quick **sanity check** over workflows and reports

This PR is **documentation + helper script only**.  
It does **not** modify any workflows, security code, or dashboard
logic.

---

## 1. Related PRs

The following PRs are part of the wave:

- **#280 — WO Dashboard Hardening**
  - Area: dashboard security (WO ID sanitization, canonical JSON,
    auth-token removal)
  - Files: `apps/dashboard/wo_dashboard_server.js`
  - Reports:
    - `g/reports/system/pr280_verification_complete_20251115.md`
    - `g/reports/system/deployment_20251115_052838.md`

- **#283 — Phase2 Sandbox Hardening**
  - Area: Codex sandbox & dashboard guardrails
  - Status: merged into `main`
  - Notes: followup/state path corrected and aligned with tooling.

- **#287 — Multi-Agent Governance Contract**
  - Area: documentation / governance only
  - Reports:
    - `g/reports/system/governance_lock_in_20251115.md`

- **#288 — Telemetry Schema Fix**
  - Area: schema alignment for telemetry + CI
  - Files: schemas under `g/schemas/` (no code runtime changes)
  - Reports:
    - `g/reports/system/telemetry_schema_ci_fix_20251115.md`

- **#289 — CI Infrastructure Improvements**
  - Area: CI workflows (Memory Guard, Path Guard, Codex sandbox)
  - Files: `.github/workflows/*.yml`, `tools/check_memory_guard.zsh`
  - Reports:
    - `g/reports/system/codex_sandbox_workflow_fix_20251115.md`
    - `g/reports/system/memory_guard_zsh_fix_20251115.md`

- **#290 — Orchestrator Restore**
  - Area: tooling (ZSH orchestrator)
  - Files: `tools/claude_subagents/orchestrator.zsh`
  - Reports:
    - `g/reports/system/orchestrator_restore_20251115.md`

- **(New)** — Orchestrator Summary v2
  - Area: tooling (summary JSON only)
  - Files:
    - `tools/claude_subagents/orchestrator.zsh`
    - `g/reports/system/orchestrator_summary_v2_feature_20251116.md`

- **(New)** — WO History / Timeline View
  - Area: dashboard UI only
  - Files:
    - `apps/dashboard/index.html`
    - `apps/dashboard/dashboard.js`
    - `g/reports/system/wo_history_timeline_feature_20251116.md`

---

## 2. Sanity Check Helper

To make sure nothing from this wave has gone missing and that key
workflows still exist on disk, use:

```bash
cd ~/02luka/g
./tools/ci_wave_sanity_check.zsh
```

What it does:
1.Verifies directories:
•.github/workflows
•g/reports/system
2.Checks presence of key workflows (read-only):
•ci.yml
•codex_sandbox.yml
•memory_guard.yml
•path_guard.yml
•system-telemetry-v2.yml
3.Shows last git commit touching each workflow, for quick forensic
checks.
4.Confirms presence of the main system reports from this wave:
•Deployment, governance lock-in, telemetry, sandbox, memory guard,
orchestrator restore, orchestrator summary v2, WO history feature.

The script is read-only: it doesn’t change workflows, reports, or
any repo content.

⸻

3. Risk & Impact
•No workflow YAML is modified.
•No security-sensitive code is changed.
•No dashboard or server code is touched.
•The helper script is entirely optional and safe to run at any
time.

Risk level: Low.

Use this PR as a “wave index” and sanity helper before starting the
next feature cycle.

⸻
