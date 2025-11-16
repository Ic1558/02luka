# save.sh Full-Cycle Test — CI Integration (2025-11-15)

## Summary

This PR wires the existing **save.sh full-cycle test harness** into GitHub
Actions as a **manual workflow**, without changing `save.sh` itself and without
adding any automatic triggers on push/PR.

The goal is to:
- Allow operators or agents to run the test remotely.
- Keep the contract between CLS/CLC lanes and CI aligned.
- Avoid any surprise CI failures until the test is proven stable.

## Files

- `.github/workflows/save_full_cycle_test.yml`
  - Adds a `Save Full-Cycle Test` workflow.
  - Trigger: `workflow_dispatch` only.
  - Input: `lane` (cls, clc, both).
  - Steps:
    - Checkout repo.
    - `chmod +x tools/tests/save_full_cycle_test.zsh`
    - Run the test for the selected lane(s).
    - Upload generated reports as artifacts.

- `tools/tests/save_full_cycle_test.zsh`
  - (Existing from previous PR)
  - Lane-aware harness (`SAVE_LANE=cls|clc`).
  - Writes reports under `g/reports/system/save_sh_full_cycle_test_*.md`.
  - Emits a machine-readable summary block.

## Behavior

- **No changes** to `save.sh` behavior.
- **No automatic CI trigger**:
  - The workflow runs only when explicitly invoked from the Actions tab.
- Compatible with both lanes:
  - CLS → `lane=cls`
  - CLC → `lane=clc`
  - Dual → `lane=both` for comparison.

## Risk

- CI-only change, read-only against repo state.
- If the test fails, it only affects manually triggered runs.

Risk level: **Low**.

## Usage

From GitHub Actions UI:

1. Go to **Actions → Save Full-Cycle Test**.
2. Click **Run workflow**.
3. Select lane:
   - `cls`
   - `clc`
   - `both`
4. Start the run.
5. After completion, download `save_sh_full_cycle_reports` artifacts and read:
   - `g/reports/system/save_sh_full_cycle_test_*.md`

This keeps the save.sh test harness visible and verifiable from CI without
changing any existing pipelines.
