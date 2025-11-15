# PR Prompt Contract · AP/IO v3.1 Hybrid Integration (Phase 3)

**Date:** 2025‑11‑16  
**Owner:** Andy (implementation) · CLS (review) · Liam (sponsor)  
**Feature:** Hybrid WO execution → AP/IO v3.1 ledger coverage  
**Scope gate:** Phase 3 “Real Integration – Hybrid” from SPEC/PLAN

---

## 1. Background & Motivation
- Phases 1–2 delivered the v3.1 protocol, schemas, validator, writer/reader, correlation utilities, and 10/10 passing protocol tests.
- Ledger extension fields (`ledger_id`, `parent_id`, `execution_duration_ms`) are live in writer/schema/docs, and the `pretty_print.zsh` viewer is available.
- Hybrid/Luka CLI remains the only daily WO executor without AP/IO logging, so production work orders still lack `task_start`/`task_result` evidence in `g/ledger/hybrid/*`.

**Goal:** Wrap every Hybrid WO execution (manual or automated) with AP/IO v3.1 writer hooks so timelines, durations, and parent/child relationships are observable in the ledger.

---

## 2. Deliverables (Must Ship in PR)
1. **Execution Wrapper:** `tools/hybrid_wo_wrapper.zsh` (new) that:
   - accepts a WO file or ID + command payload,
   - captures precise millisecond start/end timestamps,
   - generates/propagates a single correlation_id per WO,
   - writes AP/IO `task_start` immediately and `task_result` (or `error`) after execution, including `parent_id=parent-wo-$WO_ID`.
2. **Pipeline Hook:** modify the Hybrid WO entry point (existing Luka CLI script or LaunchAgent target) to route every execution through the wrapper while preserving current CLI UX.
3. **Status Updates:** extend `agents/hybrid/ap_io_v31_integration.zsh` (or add companion helper) to mirror CLS behavior: set `state=busy/idle`, record `last_task_id`, and persist new `protocol_version`.
4. **Integration Test:** `tests/ap_io_v31/test_hybrid_integration.zsh` that:
   - runs wrapper in an isolated temp ledger (`LEDGER_BASE_DIR=$(mktemp -d)`),
   - asserts both start/result events exist with identical correlation_id,
   - verifies `execution_duration_ms` positive, `parent_id` format, schema validation via `tools/ap_io_v31/validator.zsh`.
5. **Documentation Update:** short “Hybrid WO logging” section inside `docs/AP_IO_V31_PROTOCOL.md` (or companion integration guide) describing CLI usage plus manual verification commands.

---

## 3. Implementation Plan
### 3.1 Identify Execution Boundaries
- Inspect `tools/wo_pipeline/wo_executor.zsh`, `tools/wo_pipeline/lib_wo_common.zsh`, and any Hybrid-only launch scripts (e.g., `WO-*.zsh`, `tools/hybrid_ledger_hook.zsh`) to determine:
  - canonical WO ID format (`normalize_wo_id` already exists),
  - entry command invoked by Luka CLI / LaunchAgent,
  - where exit codes are surfaced.
- Outcome: concrete list of scripts/function names that must invoke `hybrid_wo_wrapper.zsh`.

### 3.2 Wrapper Behavior
Pseudo-flow:
```bash
#!/usr/bin/env zsh
set -euo pipefail

WO_ID="$(normalize_wo_id "$1")"
CORR_FILE="${TMPDIR:-/tmp}/apio_hybrid_${WO_ID}.corr"
[[ -f "$CORR_FILE" ]] || CORR_FILE="$(mktemp)"
CORR_ID="$(cat "$CORR_FILE" 2>/dev/null || "$TOOLS/ap_io_v31/correlation_id.zsh")"

WO_START_TS=$(python3 - <<'PY'); ... # milliseconds

LEDGER_CMD=("$TOOLS/ap_io_v31/writer.zsh" hybrid ...)
LEDGER_CMD+=( "$WO_ID" "hybrid" "WO started: $WO_ID" '{"status":"started"}' "parent-wo-$WO_ID" "" "$CORR_ID" )
```

Key rules:
- Reuse correlation_id between start/result (store in temp file or env var).
- Always pass `parent_id="parent-wo-$WO_ID"` and forward optional `parent_id` argument when wrapper is nested (e.g., Hybrid calling CLS).
- On completion, compute `execution_duration_ms=END_MS-START_MS`, evaluate `STATUS` from exit code, and include stdout/stderr tail (max 1 KB) sanitized.
- Never fail the WO even if ledger write fails (warn to stderr, continue).

### 3.3 Status & Telemetry
- Enhance `agents/hybrid/ap_io_v31_integration.zsh` to:
  - write `protocol` + `protocol_version` + `last_heartbeat` similar to CLS script,
  - update `status.json` location (create file if missing).
- If `status.json` absent, initialize minimal JSON with `state:"idle"`.

### 3.4 Pipeline Hook
- If WO pipeline already has `tools/hybrid_ledger_hook.zsh`, refactor it to call the new wrapper (keeping API compatibility for existing scripts like `tools/hybrid_audit_with_ledger.zsh`).
- For LaunchAgent/CLI entry (e.g., `scripts/drop_mobile_wo.sh` or `WO-xxx.zsh`), replace direct `tools/wo_pipeline/wo_executor.zsh` calls with:
  ```bash
  tools/hybrid_wo_wrapper.zsh "$STATE_FILE" \
    --exec "tools/wo_pipeline/wo_executor.zsh" \
    --args "$STATE_FILE"
  ```
- Add optional passthrough for `LEDGER_BASE_DIR` (test isolation), `HYBRID_LEDGER_DISABLE=1` (debug override), and structured logging.

### 3.5 Testing & Tooling
- Unit-style validations inside wrapper (shell functions verifying inputs).
- New test script should:
  1. create temp WO file,
  2. run wrapper with dummy `sleep 0.1` executor,
  3. parse ledger via `tools/ap_io_v31/reader.zsh --agent hybrid`,
  4. assert counts using `jq`.
- Update `tools/run_ap_io_v31_tests.zsh` and `tools/test_agent_ledger_writes.zsh` to include Hybrid wrapper scenario.

---

## 4. File Touch List
| Type | Path | Notes |
|------|------|-------|
| **Create** | `tools/hybrid_wo_wrapper.zsh` | primary wrapper, documented usage header |
|  | `tests/ap_io_v31/test_hybrid_integration.zsh` | mktemp ledger, schema validate |
| **Modify** | `agents/hybrid/ap_io_v31_integration.zsh` | state management, correlation awareness |
|  | `tools/hybrid_ledger_hook.zsh` & `tools/hybrid_audit_with_ledger.zsh` | delegate to wrapper, ensure backward compatibility |
|  | `tools/run_ap_io_v31_tests.zsh`, `tools/test_agent_ledger_writes.zsh` | add wrapper/test entries |
|  | `docs/AP_IO_V31_PROTOCOL.md` (or integration guide) | describe Hybrid hooks & verification commands |
| **Optional** | LaunchAgent / WO scripts referencing legacy hook | update invocation to wrapper while keeping governance restrictions in mind |

---

## 5. Test & Verification Plan
### Automated
1. `tests/ap_io_v31/test_hybrid_integration.zsh` (new)  
   - `LEDGER_BASE_DIR=$(mktemp -d)`  
   - ensures start/result records exist, durations positive, schema valid.
2. `tools/run_ap_io_v31_tests.zsh` – confirm new test is wired in and full suite still green.
3. `tools/test_agent_ledger_writes.zsh` – extend to hit wrapper path; ensures ledger file created and status update valid JSON.

### Manual
```bash
# Dry-run a WO (use lightweight command)
tools/hybrid_wo_wrapper.zsh ./bridge/inbox/CLC/WO-TEST.yaml --exec "sleep" --args "1"

# Inspect ledger
tools/ap_io_v31/pretty_print.zsh g/ledger/hybrid/$(date +%Y-%m-%d).jsonl --timeline

# Filter by correlation id from output
tools/ap_io_v31/reader.zsh g/ledger/hybrid/$(date +%Y-%m-%d).jsonl --correlation corr-20251116-***
```

### Acceptance Criteria
- [ ] Every WO routed through Hybrid pipeline logs `task_start` and `task_result/error` with identical correlation_id.
- [ ] `execution_duration_ms` is recorded and positive for all completed WOs (±100 ms tolerance vs. wall clock).
- [ ] `parent_id` matches `parent-wo-<normalized id>`; schema validator passes for every entry.
- [ ] `agents/hybrid/status.json` reflects busy/idle transitions and records protocol metadata.
- [ ] `tests/ap_io_v31/test_hybrid_integration.zsh` and full AP/IO suite pass locally.
- [ ] No measurable regression (>50 ms) to WO wall time; wrapper overhead documented.

---

## 6. Safety, Governance & Rollback
- Operate only inside `tools/`, `agents/hybrid/`, `tests/ap_io_v31/`, `docs/**` (allowed zones). Avoid `/CLC`, `/core/governance`, launchd plists unless explicitly approved.
- Wrapper must degrade gracefully: on writer failure log `⚠️ Hybrid ledger write failed` but continue WO.
- Add `HYBRID_LEDGER_DISABLE=1` escape hatch for emergency rollback without reverting code.
- Provide `git revert <commit>` instructions in PR description referencing single changeset touching pipeline.

---

## 7. Verification & Handoff
1. Attach sample ledger snippet (scrubbed IDs) in PR body showing start/result pair from wrapper test.
2. Share `tools/ap_io_v31/pretty_print.zsh --timeline` screenshot/log to CLS for review.
3. After merge, monitor `g/ledger/hybrid/<today>.jsonl` for 24 h; ensure no missing WOs.
4. Once stable, greenlight proceeding to Phase 4 (Andy Codex CLI integration).

---

**Ready for development. Execute once approvals for Hybrid tools are confirmed.**
