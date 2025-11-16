# Reality Hooks Advisory Check — CI Integration (2025-11-15)

## Summary

This PR adds a **non-blocking advisory check** for Reality Hooks snapshots. It
reads the latest `reality_hooks_snapshot_*.json` and produces a Markdown report
with a human-readable summary of:

- Deployment report presence
- `save.sh` full-cycle test status (CLS/CLC lanes, layers)
- Orchestrator summary availability

The advisory is **read-only** and **cannot fail CI**.

## Files

- **`tools/reality_hooks_advisory_check.zsh`**
  - Reads latest `g/reports/system/reality_hooks_snapshot_*.json`.
  - When `jq` is available:
    - Extracts:
      - `timestamp`
      - `deployment_report.path`
      - `save_sh_full_cycle[]`
      - `orchestrator_summary`
    - Computes:
      - `save_summary` (total, ok, degraded).
      - `save_issues` (non-ok runs, if any).
  - Outputs:
    - `g/reports/system/reality_hooks_advisory_<timestamp>.md`
    - `g/reports/system/reality_hooks_advisory_latest.md` (symlink or copy).
  - Always exits with code **0**.

- **`.github/workflows/reality_hooks_advisory.yml`**
  - Workflow: **Reality Hooks Advisory**
  - Trigger: `workflow_dispatch` only.
  - Steps:
    - Checkout repo.
    - Run `tools/reality_hooks_advisory_check.zsh`.
    - Upload advisory reports as `reality_hooks_advisory_reports` artifact.

## Relationship to previous PRs

This PR assumes the following PRs have been merged:

- **Reality Hooks aggregator**:
  - `tools/reality_hooks_aggregate.zsh`
  - `.github/workflows/reality_hooks.yml`
- **Reality Snapshot dashboard view**:
  - `/api/reality/snapshot` + dashboard **Reality** tab
- **save.sh full-cycle test CI**:
  - `save_full_cycle_test.yml`
  - `save_sh_full_cycle_test_*.md` with summary markers
- **Orchestrator summary report**:
  - `claude_orchestrator_summary.json`

The advisory check **only consumes** these signals; it does not modify or gate
them.

## Behavior

- If no snapshot exists:
  - Marks snapshot timestamp as `no_snapshot`.
  - Advises `no_data` for all sections.
- If snapshot exists but no save.sh runs:
  - Advises `no_data` for save.sh.
- If some save.sh runs have degraded layers:
  - Advises `degraded` and includes JSON for non-ok runs.
- If orchestrator summary is missing:
  - Advises `no_data` for orchestrator.

## Risk

- No changes to application code or security behavior.
- No changes to existing CI workflows.
- Advisory is informational only.

Risk level: **Low**.
