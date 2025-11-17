# Feature PLAN: `tools/save.sh` Full-Cycle Test Harness

**Date:** 2025-11-15  
**Owner:** Tools & Observability  
**Status:** ✅ Plan active

---

## Phase 1 — Contract + Instrumentation
- [x] Create `tools/save.sh` with:
  - Structured start/end markers and repo metadata logging.
  - Snapshot files under `logs/save_sh/`.
  - Explicit reminder that commits/pushes stay manual.
  - Optional MLS hook gated by `LUKA_MLS_AUTO_RECORD`.
- [x] Verify script exits non-zero when git context missing.

## Phase 2 — Lane Harnesses
- [x] Add `tools/save_sh/full_cycle_cls.zsh` and `tools/save_sh/full_cycle_clc.zsh`.
- [x] Ensure each harness:
  - Sets `SAVE_SH_LANE` + MLS auto-record.
  - Captures logs to `logs/save_sh/tests/`.
  - Diff-checks git status before/after and inspects MLS ledger.
- [x] Fail fast if MLS record absent or git tree mutates.

## Phase 3 — Documentation & Reporting
- [x] Publish SPEC + PLAN (this doc) at `g/reports/feature_save_sh_full_cycle_test_*.md`.
- [x] Capture execution evidence in `g/reports/system/save_sh_full_cycle_test_REPORT.md`.
- [x] Note follow-ups (if any) for future automation (e.g., adding CI wiring).

## Rollout & Ownership
- Rollout is immediate; scripts live alongside other tooling.
- Ownership: Tools & Observability maintains `save.sh` + harness.
- Risk: Low. No production services touched.

## Validation Checklist
- [x] Manual run of `tools/save_sh/full_cycle_cls.zsh` on clean tree.
- [x] Manual run of `tools/save_sh/full_cycle_clc.zsh` on clean tree.
- [x] Confirm MLS ledger entries for both lanes.

---

**Next Steps:** Monitor usage feedback; consider wiring harness into CI later.
