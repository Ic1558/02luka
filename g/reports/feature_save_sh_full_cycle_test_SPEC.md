# Feature SPEC: `tools/save.sh` Full-Cycle Test Harness

**Date:** 2025-11-15  
**Owner:** Tools & Observability  
**Scope:** `tools/save.sh`, `tools/save_sh/*`, MLS hooks, governance reports  
**Goal:** Ensure `tools/save.sh` has a deterministic contract, optional MLS telemetry, and automated full-cycle coverage across both CLS (Cursor) and CLC (Claude Code) lanes.

---

## 1. Problem Statement

`tools/save.sh` was an undocumented helper that frequently confused operators:
- No clear indication that it should *not* commit or push.
- Logs were ad-hoc, making it hard to verify runs.
- Observability gaps: no start/end markers, no way to attribute runs to a lane, and no automated MLS trace.
- No regression harness to verify that CLS and CLC flows behave identically.

---

## 2. Objectives

1. **Contract Clarity** – Define `save.sh` as a "workspace snapshot" command that:
   - Emits structured start/end markers.
   - Captures repo metadata and git state without mutating the tree.
   - Signals success/failure strictly through exit code.
2. **Opt-In MLS Telemetry** – When `LUKA_MLS_AUTO_RECORD=1`, record a lesson/solution entry describing the save cycle.
3. **Lane Coverage** – Ship repeatable `full_cycle_cls.zsh` and `full_cycle_clc.zsh` harnesses that:
   - Export `SAVE_SH_LANE` appropriately.
   - Enforce MLS auto-recording for the test.
   - Capture exit code, git status delta, and MLS verification.
4. **Governance Reporting** – Produce SPEC, PLAN, and REPORT artifacts that document the feature and its execution.

---

## 3. Functional Requirements

1. `tools/save.sh`
   - Runs on any lane via `SAVE_SH_LANE` env var (default `UNSPECIFIED`).
   - Writes git status + diff stat snapshot to `logs/save_sh/save_<ts>.log`.
   - Prints manual-commit reminder and never runs `git commit`/`git push`.
   - Emits `=== save.sh:start ... ===` and matching `=== save.sh:end ... ===` markers.
   - On MLS opt-in, invokes `tools/mls_auto_record.zsh` with a deterministic title (`save.sh full-cycle (<lane>)`).
2. `tools/save_sh/full_cycle_cls.zsh`
   - Runs from repo root, exports `SAVE_SH_LANE=CLS`, `LUKA_MLS_AUTO_RECORD=1`.
   - Pipes `save.sh` output to a lane-specific log and records `pipestatus`.
   - Verifies git status is unchanged and MLS ledger contains the CLS marker.
   - Exits non-zero if `save.sh` fails, git state differs, or MLS record missing.
3. `tools/save_sh/full_cycle_clc.zsh`
   - Mirrors the CLS harness but runs with `SAVE_SH_LANE=CLC` (SOT repo path configurable via env).
4. Documentation / Reporting
   - SPEC & PLAN capture intent and rollout steps.
   - REPORT summarizes both lane runs, their artifacts, and any follow-ups.

---

## 4. Non-Functional Requirements

- **Safety:** No git mutations beyond read-only commands.
- **Observability:** Logs stored under `logs/save_sh`, MLS entries tagged `save.sh` + lane.
- **Portability:** Works in macOS/Linux shells with Bash + Zsh available.
- **Failure Transparency:** Non-zero exit codes propagate, and harness scripts print context.

---

## 5. Success Criteria

- `tools/save.sh` documents its behavior via logs + markers and respects opt-in MLS recording.
- Running each `full_cycle_*.zsh` script yields exit code 0 on a clean tree and records an MLS entry.
- Governance artifacts (SPEC/PLAN/REPORT) live under `g/reports/*`.
- Normal users see no change unless they opt into MLS, yet benefit from clearer output.

---

**Status:** ✅ SPEC approved for implementation.
