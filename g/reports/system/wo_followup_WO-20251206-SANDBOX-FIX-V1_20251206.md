# WO Followup Report: WO-20251206-SANDBOX-FIX-V1

**Date:** 2025-12-06  
**WO ID:** WO-20251206-SANDBOX-FIX-V1  
**Title:** sandbox: fix disallowed command patterns in docs/scripts  
**Target:** CLC  
**Priority:** P2

---

## Status Summary

**Current Status:** ⏳ **Pending - Assigned but not started**

**WO Location:**
- ✅ Inbox: `bridge/inbox/CLC/WO-20251206-SANDBOX-FIX-V1.yaml`
- ✅ Outbox: `bridge/outbox/CLC/WO-20251206-SANDBOX-FIX-V1.yaml`
- ⏳ Processed: Not yet moved to `bridge/processed/CLC/`

---

## Task Validation

### T1: Scan violations
**Status:** ❌ Not started  
**Expected:** Scan repo for matches against `schemas/codex_disallowed_commands.yaml`  
**Current:** Sandbox check shows **23 violations** still present  
**Evidence:**
```
❌ Codex sandbox check failed – 23 violation(s) found:
  [rm_rf] → agents/liam/mary_router_integration_example.py:123
  [rm_rf] → context/safety/gm_policy_v4.yaml:53
  [rm_rf] → g/tools/artifact_validator.zsh:57
  [rm_rf] → governance/overseerd.py:113
  ... (19 more violations)
```

### T2: Classify matches
**Status:** ❌ Not started  
**Expected:** Categorize violations as (A) code, (B) docs, (C) test fixtures  
**Current:** No classification report exists

### T3: Fix code
**Status:** ❌ Not started  
**Expected:** Refactor dangerous patterns in executable scripts  
**Current:** No code changes detected

### T4: Fix docs
**Status:** ❌ Not started  
**Expected:** Adjust documentation examples to avoid regex matches  
**Current:** No documentation changes detected

### T5: Tests
**Status:** ❌ Not started  
**Expected:** Local sandbox scan passes, CI workflow passes  
**Current:** Sandbox check still failing

---

## Deliverables Check

| Deliverable | Expected | Status | Notes |
|-------------|----------|--------|-------|
| Branch | `fix/sandbox-check-violations` | ❌ Not created | No branch exists |
| Report | `g/reports/sandbox_fix_summary_*.md` | ❌ Not created | No report file found |
| Tool (optional) | `g/tools/sandbox_scan.py` | ⚠️ Not created | Optional, acceptable |

---

## Acceptance Criteria Validation

| Criteria | Status | Evidence |
|----------|--------|----------|
| No code violations | ❌ Fail | 23 violations still present |
| Docs compliant | ❌ Fail | No docs fixes applied |
| Sandbox CI passes | ❌ Fail | Workflow still failing |
| Summary report exists | ❌ Fail | No report generated |

---

## Current Violations (Sample)

**Found:** 23 violations across multiple files

**Top violations:**
1. `agents/liam/mary_router_integration_example.py:123` - `rm -rf /`
2. `context/safety/gm_policy_v4.yaml:53` - `rm -rf`
3. `g/tools/artifact_validator.zsh:57` - `rm -rf "$ARTIFACT_DIR"`
4. `governance/overseerd.py:113` - `rm -rf /` (in check logic)
5. Multiple test files with intentional dangerous patterns

**Patterns detected:**
- `rm_rf` (most common)
- `superuser_exec` (sudo)
- Others (see full scan output)

---

## Score: 0/10

### Scoring Breakdown

| Category | Points | Score | Notes |
|----------|--------|-------|-------|
| Task T1 (Scan) | 2 | 0/2 | Not started |
| Task T2 (Classify) | 2 | 0/2 | Not started |
| Task T3 (Fix code) | 2 | 0/2 | Not started |
| Task T4 (Fix docs) | 2 | 0/2 | Not started |
| Task T5 (Tests) | 1 | 0/1 | Not started |
| Deliverables | 1 | 0/1 | None created |
| **Total** | **10** | **0/10** | |

---

## Recommendations

1. **CLC should pick up WO** from `bridge/inbox/CLC/`
2. **Start with T1:** Run sandbox scan and create violation report
3. **Create branch:** `fix/sandbox-check-violations` for implementation
4. **Prioritize code fixes:** Address real script violations first (T3)
5. **Then fix docs:** Adjust documentation examples (T4)
6. **Verify:** Run local scan and ensure CI passes (T5)

---

## Next Steps

1. CLC reads WO from `bridge/inbox/CLC/WO-20251206-SANDBOX-FIX-V1.yaml`
2. Creates branch: `fix/sandbox-check-violations`
3. Executes T1: Scans and documents all violations
4. Proceeds with T2-T5 sequentially
5. Creates summary report upon completion

---

**Report Generated:** 2025-12-06  
**Next Review:** After CLC starts implementation
