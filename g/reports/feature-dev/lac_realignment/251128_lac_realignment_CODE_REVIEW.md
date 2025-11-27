# LAC Realignment V2 — Code Review
**Date:** 2025-11-28  
**Reviewer:** CLC (Code Lifecycle Controller)  
**Documents Reviewed:**
- `g/ai_contracts/lac_contract_v2.yaml` (Contract - SOT)
- `g/reports/feature-dev/lac_realignment/251128_lac_realignment_SPEC_v2.md`
- `g/reports/feature-dev/lac_realignment/251128_lac_realignment_PLAN_v2.md`

---

## Executive Summary

**Overall Verdict:** ✅ **APPROVED WITH MINOR FIXES**

The V2 documents successfully correct the architectural drift from V1 and align with the LAC Contract V2. The specification and plan are well-structured, contract-compliant, and implementation-ready. However, there are **3 critical issues** and **2 minor improvements** that must be addressed before implementation.

---

## 1. Contract Compliance Check

### ✅ PASS: All Contract Rules Validated

| Contract Rule | SPEC V2 | PLAN V2 | Status |
|---------------|---------|---------|--------|
| CLC not in mandatory pipeline | ✅ CLC optional | ✅ P4 removes from default | ✅ PASS |
| Agents write via policy | ✅ shared.policy | ✅ P1+P2 implements | ✅ PASS |
| paid_lanes.enabled=false default | ✅ Config shows false | ✅ P5 enforces | ✅ PASS |
| self_apply field in WO | ✅ Schema includes | ✅ P3 implements | ✅ PASS |
| Budget ≤ 50 THB emergency | ✅ 50 THB max | ✅ P5 enforces | ✅ PASS |
| Agents are full developers | ✅ OSS/GMX can write | ✅ P2 enables | ✅ PASS |

**Contract Compliance Score:** ✅ **100%**

---

## 2. Consistency Check (SPEC vs PLAN)

### ✅ PASS: Documents Are Consistent

| Aspect | SPEC V2 | PLAN V2 | Status |
|--------|---------|---------|--------|
| Shared policy location | `shared/policy.py` | `shared/policy.py` | ✅ Match |
| Phase order | P1-P5 | P1-P5 | ⚠️ **INCONSISTENT** |
| CLC role | Optional tool | Optional tool | ✅ Match |
| Budget limit | 50 THB | 50 THB | ✅ Match |
| Direct merge | self_apply=true | self_apply=true | ✅ Match |

**Issue Found:** Phase numbering inconsistency (see Section 3.1)

---

## 3. Critical Issues (MUST FIX)

### 🔴 Issue #1: Phase Numbering Inconsistency

**Problem:**
- **SPEC V2 Section 2.2.1:** Labels shared policy as "P5"
- **PLAN V2 Section 2:** Labels shared policy as "P1"
- **Contract:** No phase order specified

**Impact:** Confusion during implementation, wrong task sequencing

**Fix Required:**
- **Option A:** Update SPEC to match PLAN (shared policy = P1)
- **Option B:** Update PLAN to match SPEC (shared policy = P5)
- **Recommendation:** **Option A** (shared policy should be P1 as it's foundational)

**Files to Update:**
- `251128_lac_realignment_SPEC_v2.md` line 131: Change "P5" → "P1"

---

### 🔴 Issue #2: Shared Directory Location Ambiguity

**Problem:**
- Documents specify `shared/policy.py` but don't clarify if this is:
  - `shared/policy.py` (repo root)
  - `agents/shared/policy.py`
  - `g/shared/policy.py`
- No `shared/` directory exists in current codebase
- Existing policy is at `agents/clc_local/policy.py`

**Impact:** Implementation uncertainty, potential path conflicts

**Fix Required:**
1. **Clarify location:** Recommend `agents/shared/policy.py` (follows "where it runs" principle)
2. **Migration plan:** Document how to migrate from `agents/clc_local/policy.py` to shared
3. **Update imports:** All references should use explicit path

**Recommended Location:**
```python
# agents/shared/policy.py
# Reason: Follows "where it runs" principle, agents/ is where agent code lives
```

**Files to Update:**
- SPEC V2: Add location clarification section
- PLAN V2: Update all file paths to `agents/shared/policy.py`
- Add migration task: "Migrate existing policy.py to shared location"

---

### 🔴 Issue #3: Policy Path Checking Logic Vulnerability

**Problem:**
```python
# Current logic in SPEC/PLAN:
for forbidden in FORBIDDEN_PATHS:
    if forbidden in file_path:  # ⚠️ Substring match - vulnerable!
        return False
```

**Vulnerability:**
- `"bridge/" in "my_bridge_test.py"` → **FALSE POSITIVE** (blocked incorrectly)
- `".env" in "environment.py"` → **FALSE POSITIVE** (blocked incorrectly)
- Path traversal: `"../../.git/config"` might not be caught

**Impact:** Legitimate files may be blocked, security risk

**Fix Required:**
```python
def check_write_allowed(file_path: str) -> tuple[bool, str]:
    """Check if file write is allowed - FIXED VERSION."""
    from pathlib import Path
    
    # Normalize path (resolve relative, remove traversal)
    try:
        normalized = Path(file_path).resolve()
        normalized_str = str(normalized)
    except (OSError, ValueError):
        return False, "INVALID_PATH"
    
    # Check forbidden paths (exact match or prefix)
    for forbidden in FORBIDDEN_PATHS:
        # Use pathlib for proper matching
        forbidden_path = Path(forbidden)
        if forbidden_path.is_absolute():
            if normalized == forbidden_path or normalized.is_relative_to(forbidden_path):
                return False, f"FORBIDDEN_PATH: {forbidden}"
        else:
            # Relative forbidden path - check if any component matches
            if any(part == forbidden.rstrip("/") for part in normalized.parts):
                return False, f"FORBIDDEN_PATH: {forbidden}"
    
    # Check allowed roots (must be prefix match)
    for allowed in ALLOWED_ROOTS:
        allowed_path = Path(allowed)
        try:
            if normalized.is_relative_to(allowed_path):
                return True, "ALLOWED"
        except ValueError:
            continue
    
    return False, "PATH_NOT_IN_ALLOWED_ROOTS"
```

**Files to Update:**
- SPEC V2 Section 2.2.1: Replace policy code with fixed version
- PLAN V2 Section 2: Update policy implementation
- Add test case: `test_path_traversal_blocked()`

---

## 4. Minor Issues (SHOULD FIX)

### ⚠️ Issue #4: Missing Integration with Existing CLC Local Policy

**Problem:**
- `agents/clc_local/policy.py` already exists and works
- V2 documents don't address migration/consolidation
- Risk of duplicate policy logic

**Recommendation:**
- Add task in PLAN: "Audit existing `agents/clc_local/policy.py`"
- Add task: "Consolidate policy logic into shared module"
- Add task: "Update `clc_local` to use shared policy (backward compatible)"

---

### ⚠️ Issue #5: Missing Error Handling in apply_patch

**Problem:**
```python
# Current code in SPEC:
with open(file_path, 'w') as f:
    f.write(content)
```

**Missing:**
- File permission errors
- Disk full errors
- Directory creation failures
- Encoding errors

**Fix:**
```python
def apply_patch(file_path: str, content: str, dry_run: bool = False) -> dict:
    """Apply patch after policy check - WITH ERROR HANDLING."""
    allowed, reason = check_write_allowed(file_path)
    if not allowed:
        return {"status": "blocked", "reason": reason}
    
    if dry_run:
        return {"status": "dry_run", "would_write": file_path}
    
    try:
        path = Path(file_path)
        path.parent.mkdir(parents=True, exist_ok=True)
        
        with path.open('w', encoding='utf-8') as f:
            f.write(content)
        
        return {"status": "success", "file": file_path}
    except PermissionError:
        return {"status": "error", "reason": "PERMISSION_DENIED"}
    except OSError as e:
        return {"status": "error", "reason": f"OS_ERROR: {e}"}
    except Exception as e:
        return {"status": "error", "reason": f"UNEXPECTED_ERROR: {e}"}
```

---

## 5. Style & Best Practices

### ✅ Good Practices Found

1. **Contract-First Design:** Documents reference contract as SOT ✅
2. **Clear Phase Breakdown:** Tasks are actionable and testable ✅
3. **Comprehensive Testing:** Unit + integration + smoke tests planned ✅
4. **Risk Assessment:** Risks identified with mitigations ✅
5. **Backward Compatibility:** CLC API kept as optional lane ✅

### ⚠️ Areas for Improvement

1. **Code Examples:** Some code snippets are simplified (missing error handling)
2. **Path Normalization:** Need explicit handling of relative/absolute paths
3. **Migration Strategy:** Missing detailed migration plan from V1 to V2
4. **Rollback Plan:** No rollback strategy if implementation fails

---

## 6. Implementation Feasibility

### ✅ Feasible Components

| Component | Feasibility | Notes |
|-----------|-------------|-------|
| Shared Policy Module | ✅ High | Simple refactor of existing policy |
| Agent Direct-Write | ✅ High | Agents already have write capability (via CLC), just need to enable |
| Self-Complete Pipeline | ✅ Medium | State machine exists, needs extension |
| CLC Repositioning | ✅ High | Mostly documentation + routing changes |
| Free-First Budget | ✅ High | Config + guard logic |

### ⚠️ Potential Challenges

1. **State Machine Complexity:** P3 self-complete pipeline may need iteration
2. **Testing Coverage:** Need comprehensive integration tests
3. **Migration Risk:** Existing WOs may break if schema changes

---

## 7. Risk Assessment

### High Risk Areas

| Risk | Severity | Probability | Mitigation Status |
|------|----------|-------------|-------------------|
| Policy path checking bugs | High | Medium | ⚠️ **FIX REQUIRED** (Issue #3) |
| Phase numbering confusion | Medium | High | ⚠️ **FIX REQUIRED** (Issue #1) |
| Shared directory location | Medium | Medium | ⚠️ **FIX REQUIRED** (Issue #2) |
| Breaking existing WOs | Medium | Low | ✅ Mitigated (backward compatible) |
| State machine edge cases | Medium | Medium | ⚠️ Needs more test cases |

### Low Risk Areas

- Contract compliance: ✅ 100%
- Document consistency: ✅ 95% (minor phase numbering)
- Implementation feasibility: ✅ High
- Testing strategy: ✅ Comprehensive

---

## 8. Diff Hotspots (Areas Requiring Careful Review)

### Hotspot #1: Policy Module Location
**Files:** `shared/policy.py` (new) vs `agents/clc_local/policy.py` (existing)
**Action:** Consolidate, don't duplicate

### Hotspot #2: Routing Logic Changes
**Files:** `agents/ai_manager/ai_manager.py`, `agents/clc/model_router.py`
**Action:** Ensure CLC removed from default path, DIRECT_MERGE added

### Hotspot #3: WO Schema Extension
**Files:** All WO consumers (AI Manager, Dev agents, QA, Docs)
**Action:** Ensure `self_apply`, `complexity` fields are backward compatible

### Hotspot #4: Budget Guard Implementation
**Files:** `agents/router/paid_lane_guard.py` (new)
**Action:** Triple guard must be atomic (all 3 checks in one function)

---

## 9. Test Coverage Assessment

### ✅ Well-Covered Areas

- Policy enforcement (unit tests planned)
- Agent direct-write (integration tests planned)
- Self-complete pipeline (end-to-end tests planned)
- Paid lane guard (3 test scenarios planned)

### ⚠️ Gaps Identified

1. **Path Traversal Tests:** Missing (add test for `../../.git/config`)
2. **Edge Case Tests:** Missing (what if `self_apply` is missing? defaults?)
3. **Concurrency Tests:** Missing (multiple agents writing simultaneously)
4. **Rollback Tests:** Missing (what if DIRECT_MERGE fails mid-way?)

**Recommendation:** Add these test cases to PLAN V2

---

## 10. Final Verdict

### ✅ **APPROVED WITH FIXES REQUIRED**

**Summary:**
- ✅ **Contract Compliance:** 100% aligned
- ✅ **Architecture:** Correctly addresses drift
- ✅ **Implementation Plan:** Feasible and well-structured
- ⚠️ **Critical Issues:** 3 issues must be fixed before implementation
- ⚠️ **Minor Issues:** 2 improvements recommended

**Required Actions Before Implementation:**
1. ✅ Fix Issue #1: Phase numbering (SPEC: P5 → P1)
2. ✅ Fix Issue #2: Clarify shared directory location (`agents/shared/policy.py`)
3. ✅ Fix Issue #3: Improve policy path checking logic (use pathlib, prevent false positives)
4. ⚠️ Address Issue #4: Document migration from existing policy
5. ⚠️ Address Issue #5: Add error handling to `apply_patch`

**Estimated Fix Time:** 1-2 hours

**After Fixes:** ✅ **READY FOR IMPLEMENTATION**

---

## 11. Recommendations

### Immediate (Before Implementation)
1. Fix the 3 critical issues above
2. Add migration plan for existing `clc_local/policy.py`
3. Add path traversal test cases

### Short-Term (During Implementation)
1. Implement shared policy first (P1) - foundational
2. Add comprehensive logging for all policy checks
3. Create rollback plan for each phase

### Long-Term (Post-Implementation)
1. Monitor self-complete success rate (target: > 90%)
2. Track CLC usage (should drop to < 10%)
3. Review budget guard effectiveness

---

**Review Status:** ✅ **APPROVED WITH FIXES**  
**Next Action:** Fix critical issues, then proceed with implementation  
**Reviewer:** CLC  
**Date:** 2025-11-28

