# Feature: save.sh Full-Cycle Test (CLS / CLC Parity)

Status: WIP - hooks implemented, tests manual

## Scope

- Add opt-in hooks to `tools/save.sh`:
  - `SAVE_SH_AUTOCOMMIT=1` → auto-add + commit (if any staged changes)
  - `SAVE_SH_MLS_LOG=1`    → call `tools/mls_auto_record.zsh` (if present)
- Provide lane-agnostic test harness:
  - `tools/test_save_full_cycle.zsh [cls|clc|...]`

## Non-goals

- No CI/workflow changes in this PR
- No behavior change for existing callers that do not set the new env vars

## Manual test recipe

From repo root:

```bash
tools/test_save_full_cycle.zsh cls   # CLS lane
tools/test_save_full_cycle.zsh clc   # CLC lane
```

Then verify:

- `g/tmp/save_sh_full_cycle_test.txt` exists and was appended to
- `g/reports/system/save_sh_full_cycle_test_report.md` was generated
- If MLS is wired:
  - new MLS entries referencing `source=save.sh`, `event=save`
