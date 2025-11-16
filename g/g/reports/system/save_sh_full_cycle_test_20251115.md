# save.sh Full-Cycle Test — Implementation Notes (2025-11-15)

This document describes the implementation of the **save.sh full-cycle test harness**
and how to run it from both **CLS** and **CLC** lanes.

## Scope

- Add a lane-aware test script:
  - `tools/tests/save_full_cycle_test.zsh`
- Generate test reports under:
  - `g/reports/system/save_sh_full_cycle_test_*.md`
- Do **not** change `save.sh` behavior in this PR.
- Do **not** add CI triggers yet (manual / agent-driven only).

This matches the earlier SPEC/PLAN (`feature_save_sh_full_cycle_test_SPEC/PLAN`).

## Layers exercised

Conceptually, the test touches:

1. **Layer 1 — In-memory / session**
   - Proxy signal: successful `save.sh` invocation + optional L1 marker file.
2. **Layer 2 — Local repo snapshot**
   - Checks existence of the snapshot directory (`g/snapshots` by default).
3. **Layer 3 — Local archive / reports**
   - Checks the local archive directory (`g/reports/snapshots` by default).
4. **Layer 4 — External / cloud hint**
   - Best-effort check for a sync state directory (`g/reports/sync_state` by default).

These paths are **placeholders** and may be adjusted by CLS/CLC to match the
actual `save.sh` implementation.

## Usage

From the repo root:

```bash
chmod +x tools/tests/save_full_cycle_test.zsh

# CLS lane
SAVE_LANE=cls tools/tests/save_full_cycle_test.zsh

# CLC lane
SAVE_LANE=clc tools/tests/save_full_cycle_test.zsh
```

Each run creates a report:
- `g/reports/system/save_sh_full_cycle_test_<timestamp>.md`

and prints a machine-readable summary:

```
SAVE_SH_FULL_CYCLE_SUMMARY_START
test_id=...
lane=cls|clc
layer1=ok|unknown|missing
layer2=ok|missing
layer3=ok|missing
layer4=ok|unknown
git=ok|missing|skipped
report=/path/to/report.md
SAVE_SH_FULL_CYCLE_SUMMARY_END
```

This summary can later be consumed by agents or CI jobs.

### Lanes (CLS vs CLC)

- **CLS lane (Cursor):**
  - Typically runs inside the local clone with a dev shell.
  - Can call `tools/tests/save_full_cycle_test.zsh` directly.
- **CLC lane (Claude Code):**
  - May run via remote shell / work order.
  - Should pass `SAVE_LANE=clc` and ensure `ROOT` is set appropriately.

The test script itself is lane-agnostic; it only uses the `SAVE_LANE` value
for reporting so we can compare both environments.

## Next steps (future PRs)

- Align the placeholder paths with the official `save.sh` contract.
- Optionally add a CI workflow that runs the full-cycle test in a safe
environment (e.g., `workflow_dispatch`-only).
- Integrate full-cycle results into the multi-agent telemetry stream.
