# Reality Hooks CI Integration (2025-11-15)

## Summary

This PR introduces a **passive Reality Hooks aggregator** that collects signals
from existing reports and writes a single JSON snapshot. It does **not** gate
CI or change any production behavior.

The goal is to build a foundation for reality-aware checks using:
- Deployment reports
- `save.sh` full-cycle test summaries
- Orchestrator summaries

## Files

- **`tools/reality_hooks_aggregate.zsh`**
  - Reads:
    - `g/reports/system/deployment_*.md` (latest deployment report)
    - `g/reports/system/save_sh_full_cycle_test_*.md` (last N test runs)
    - `g/reports/system/claude_orchestrator_summary.json` (orchestrator smoke)
  - Extracts:
    - `SAVE_SH_FULL_CYCLE_SUMMARY_START/END` blocks and converts them to JSON.
  - Writes:
    - `g/reports/system/reality_hooks_snapshot_<timestamp>.json`
      with the structure:

    ```jsonc
    {
      "timestamp": "20251115_053012",
      "deployment_report": {
        "path": "g/reports/system/deployment_20251115_052838.md"
      },
      "save_sh_full_cycle": [
        {
          "file": "g/reports/system/save_sh_full_cycle_test_20251115_051200.md",
          "test_id": "save_sh_full_cycle_20251115_051200",
          "lane": "cls",
          "layer1": "ok",
          "layer2": "ok",
          "layer3": "ok",
          "layer4": "unknown",
          "git": "ok"
        }
      ],
      "orchestrator_summary": { /* raw orchestrator summary JSON or null */ }
    }
    ```

- **`.github/workflows/reality_hooks_snapshot.yml`**
  - Workflow: **Reality Hooks Snapshot**
  - Trigger: `workflow_dispatch` only.
  - Steps:
    - Checkout repo.
    - Run `tools/reality_hooks_aggregate.zsh`.
    - Upload `reality_hooks_snapshot_*.json` as an artifact.

## Behavior

- No changes to:
  - `save.sh`
  - WO dashboard
  - Signature verification
  - Existing workflows
- Workflow must be triggered manually from the Actions tab.

## Risk

- Read-only aggregation + new snapshot file.
- No automatic gating or failure.

Risk level: **Low**.

## Usage

From GitHub Actions:

1. Open **Actions → Reality Hooks Snapshot**.
2. Click **Run workflow**.
3. After completion:
   - Download the `reality_hooks_snapshot` artifact.
   - Inspect `reality_hooks_snapshot_<timestamp>.json` for a compact view of:
     - Last deployment report.
     - Recent save.sh full-cycle test status (CLS / CLC).
     - Orchestrator summary.

This gives a single "reality snapshot" that other agents (Codex, CLC, GC, etc.)
can consume in follow-up work orders.
