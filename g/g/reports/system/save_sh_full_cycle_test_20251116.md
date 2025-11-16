# Feature: `save.sh` Full-Cycle Test Harness — 2025-11-16

## Summary

This feature adds a **full-cycle test harness** for `save.sh` that can
run in both **CLS** and **CLC** lanes and write structured Markdown
reports to:

- `g/reports/system/save_sh_full_cycle_CLS_<timestamp>.md`
- `g/reports/system/save_sh_full_cycle_CLC_<timestamp>.md`

The harness:

- Does **not** modify CI workflows.
- Does **not** change `save.sh` logic.
- Does **not** touch dashboard or security code.
- Only wraps `save.sh`, captures git state, and records results.

This implements the execution part of:

- `g/reports/feature_save_sh_full_cycle_test_SPEC.md`
- `g/reports/feature_save_sh_full_cycle_test_PLAN.md`

---

## Files

### New

- `tools/save_sh_full_cycle_test.zsh`
  - Helper script to:

    - Set `LUKA_LANE=CLS|CLC`
    - Run `./save.sh` from repo root
    - Capture `git status --short` before/after
    - Record branch, HEAD, last commit line
    - Write per-lane Markdown reports under `g/reports/system/`

- `g/reports/system/save_sh_full_cycle_test_20251116.md`
  - This feature report.

### Existing (referenced, not changed)

- `save.sh` (repo root)
- `g/reports/feature_save_sh_full_cycle_test_SPEC.md`
- `g/reports/feature_save_sh_full_cycle_test_PLAN.md`

---

## Behavior

From `~/02luka/g`:

```bash
# Run both lanes (default behavior)
./tools/save_sh_full_cycle_test.zsh

# Run CLS lane only
./tools/save_sh_full_cycle_test.zsh --lane cls

# Run CLC lane only
./tools/save_sh_full_cycle_test.zsh --lane clc
```

Each run:
1.Records:
•Branch + HEAD before/after
•git status --short before/after
•Last commit line after save.sh
2.Invokes:
•LUKA_LANE=<CLS|CLC> ./save.sh
3.Writes a report:
•g/reports/system/save_sh_full_cycle_<LANE>_<ISO>.md

No automatic MLS logging is triggered here; that remains a separate
concern that can be added in a later feature if desired.

---

Safety & Risk
•No .github/workflows changes.
•No apps/dashboard or server/security changes.
•No modification to save.sh itself.
•Script is local only and does not push or tag.

Risk level: Low.

---

Usage Notes
•Use this harness after making changes to save.sh or related
pipelines to validate behavior separately in CLS and CLC
environments.
•The generated reports can be attached to future PRs as “reality
hooks” showing actual observed behavior for each lane.

---

## 2. Commit messages

Suggested commits:

1. `feat(save): add save.sh full-cycle test harness for CLS/CLC`
2. `docs(save): record save.sh full-cycle test feature status`

Or squash as:

- `feat(save): add save.sh full-cycle test harness`

---

## 3. GitHub PR description block

You can use this as the PR body for the branch  
(e.g. `feature/save-sh-full-cycle-test`):

```md
## Summary

Add a **full-cycle test harness** for `save.sh` that can run in CLS and
CLC lanes, capture before/after git state, and write Markdown reports
under `g/reports/system/`.

This is tooling-only:

- ✅ No workflow YAML changes
- ✅ No dashboard or server changes
- ✅ No security file changes
- ✅ `save.sh` remains unchanged

---

## Changes

### 1. Test harness script

**`tools/save_sh_full_cycle_test.zsh`**

- Supports:

  - `--lane cls`
  - `--lane clc`
  - `--lane both` (default)

- For each lane:

  - Sets `LUKA_LANE=<CLS|CLC>`.
  - Captures:

    - `git status --short` (before + after)
    - current branch and HEAD
    - last commit line after `save.sh` runs

  - Runs:

    ```bash
    LUKA_LANE=<lane> ./save.sh
    ```

  - Writes a report:

    - `g/reports/system/save_sh_full_cycle_<LANE>_<timestamp>.md`

- The script is **read-only** with respect to workflows, dashboard, and
  security code; it only wraps your existing `save.sh`.

### 2. Feature report

**`g/reports/system/save_sh_full_cycle_test_20251116.md`**

- Documents:

  - Purpose and design of the harness.
  - Relation to:

    - `g/reports/feature_save_sh_full_cycle_test_SPEC.md`
    - `g/reports/feature_save_sh_full_cycle_test_PLAN.md`

  - Expected behavior, usage, and risk assessment.

---

## Behavior

From `~/02luka/g`:

```bash
# Run CLS and CLC lanes
./tools/save_sh_full_cycle_test.zsh

# CLS-only run
./tools/save_sh_full_cycle_test.zsh --lane cls

# CLC-only run
./tools/save_sh_full_cycle_test.zsh --lane clc
```

Each run generates per-lane Markdown reports summarizing:
•Lane name
•Exit code from save.sh
•Git branch and HEAD (before/after)
•git status --short (before/after)
•Last commit line after the run

These reports can be attached to future PRs as reality hooks
confirming how save.sh behaves in each lane.

---

Safety / Risk
•Does not change .github/workflows or any CI configuration.
•Does not touch apps/dashboard or server/security.
•Does not modify save.sh; only invokes it.
•Local only; no pushes or tags.

Risk level: Low.

---

classification

classification:
  task_type: PR_FEAT
  primary_tool: codex_cli
  needs_pr: true
  security_sensitive: false
  reason: "Adds a local test harness around save.sh for CLS/CLC lanes without changing workflows or security-sensitive code."

---

If this matches what you expect for the `save.sh` lane, this is your next PR.

When you’re ready to advance again (e.g. MLS logging integration, or another small feature lane), just say **Next**.
