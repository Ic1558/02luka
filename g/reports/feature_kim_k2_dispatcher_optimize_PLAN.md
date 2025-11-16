# Kim K2 Dispatcher — PR Readiness Score Optimization Plan

**Date:** 2025-11-12  
**Status:** Ready for Implementation  
**PR:** #272  
**Current Score:** 62.5 / 100  
**Target Score:** 80+ / 100  
**Spec:** `g/reports/feature_kim_k2_dispatcher_optimize_SPEC.md`

---

## Overview

This plan optimizes PR #272 readiness score from 62.5 to 80+ by adding documentation and tests without changing core functionality.

**Estimated Time:** 4-6 hours  
**Complexity:** Low (additive changes only)  
**Risk:** Low (no code changes, only docs/tests)

---

## Task Breakdown

### Phase 1: Documentation (1-2 hours)

#### Task 1.1: Create `core/nlp/README.md`
- [ ] Architecture overview
- [ ] Setup instructions
- [ ] Configuration guide
- [ ] API reference
- [ ] Troubleshooting section
- [ ] Examples

**Acceptance:**
- README covers all major features
- Setup instructions work
- Examples are runnable

#### Task 1.2: Create `docs/kim_k2_dispatcher.md`
- [ ] Quick start guide
- [ ] Command reference (`/use`, `/k2`)
- [ ] Profile management
- [ ] Best practices
- [ ] Common issues

**Acceptance:**
- User can follow quick start
- All commands documented
- Examples work

#### Task 1.3: Enhance inline documentation
- [ ] Add module docstrings
- [ ] Complete function docstrings
- [ ] Add type hints where missing
- [ ] Document error cases

**Acceptance:**
- All public functions documented
- Type hints complete
- Error cases explained

---

### Phase 2: Test Coverage (2-3 hours)

#### Task 2.1: Expand `tests/test_kim_profile_router.py`
- [ ] Add error handling tests
- [ ] Add edge case tests
- [ ] Add invalid input tests
- [ ] Add concurrent access tests

**Acceptance:**
- All error paths tested
- Edge cases covered
- Tests pass

#### Task 2.2: Create `tests/test_profile_store_edge_cases.py`
- [ ] TTL expiration tests
- [ ] Concurrent access tests
- [ ] Invalid data handling
- [ ] File corruption recovery

**Acceptance:**
- TTL logic verified
- Thread safety tested
- Error recovery works

#### Task 2.3: Create `tests/integration/test_kim_k2_flow.py`
- [ ] End-to-end message flow
- [ ] Redis integration
- [ ] Profile switching
- [ ] Event emission

**Acceptance:**
- Full flow works
- Redis integration verified
- Events emitted correctly

---

### Phase 3: CI & Quality (30 min)

#### Task 3.1: Fix CI Issues
- [ ] Run linter and fix issues
- [ ] Run formatter
- [ ] Verify all tests pass
- [ ] Check type hints

**Acceptance:**
- No linting errors
- All tests pass
- CI green

#### Task 3.2: Governance Check
- [ ] Verify no forbidden paths
- [ ] Check file permissions
- [ ] Verify secrets handling

**Acceptance:**
- No governance violations
- Files in correct locations

---

### Phase 4: Verification (30 min)

#### Task 4.1: Run PR Score Locally
- [ ] Install dependencies
- [ ] Run `tools/pr_score.mjs` locally
- [ ] Verify score improvement
- [ ] Check breakdown

**Acceptance:**
- Score: 80+ / 100
- All categories improved
- No regressions

#### Task 4.2: Manual Testing
- [ ] Run health check
- [ ] Test `/use` command
- [ ] Test `/k2` command
- [ ] Verify profile persistence

**Acceptance:**
- All features work
- No breaking changes

---

## Implementation Checklist

### Pre-Implementation
- [x] SPEC.md created
- [x] PLAN.md created (this file)
- [x] Current code reviewed
- [x] Score breakdown analyzed

### Implementation
- [ ] Create `core/nlp/README.md`
- [ ] Create `docs/kim_k2_dispatcher.md`
- [ ] Enhance inline documentation
- [ ] Expand unit tests
- [ ] Add integration tests
- [ ] Fix CI issues
- [ ] Run governance check

### Post-Implementation
- [ ] Verify score: 80+ / 100
- [ ] Run all tests
- [ ] Manual testing complete
- [ ] Documentation reviewed
- [ ] PR updated

---

## Test Commands

```bash
# 1. Run tests
pytest tests/test_kim_profile_router.py -v
pytest tests/test_profile_store_edge_cases.py -v
pytest tests/integration/test_kim_k2_flow.py -v

# 2. Health check
~/02luka/tools/kim_health_check.zsh

# 3. Linting
pylint core/nlp/*.py
mypy core/nlp/*.py

# 4. PR score (if possible locally)
node tools/pr_score.mjs
```

---

## Score Improvement Strategy

### Current Gaps (Estimated)

1. **Docs/tests (10%):** Currently 0.0 → Target 1.0
   - **Gain:** +10 points
   - **Action:** Add README + expand tests

2. **CI status (25%):** Unknown → Target 1.0
   - **Gain:** +0-25 points (if currently failing)
   - **Action:** Fix CI issues

3. **Freshness (10%):** Unknown → Target 1.0
   - **Gain:** +0-10 points (if stale)
   - **Action:** Update PR (if needed)

### Expected Score After Optimization

- **Minimum:** 62.5 + 10 (docs/tests) = 72.5
- **Target:** 62.5 + 10 (docs/tests) + 5-10 (CI/freshness) = 77.5-82.5
- **Goal:** 80+ / 100 ✅

---

## Rollback Plan

If issues arise:

1. **Revert documentation:** Git revert doc commits
2. **Revert tests:** Git revert test commits
3. **No code changes:** Core functionality unchanged

**Note:** Since only docs/tests are added, rollback is safe and simple.

---

## Code Review Notes

### Areas to Focus

1. **Documentation Quality:**
   - Clarity and completeness
   - Examples work
   - No outdated information

2. **Test Coverage:**
   - All paths tested
   - Edge cases covered
   - Integration tests realistic

3. **No Breaking Changes:**
   - Verify existing functionality unchanged
   - No API changes
   - Backward compatible

---

## Success Metrics

- ✅ Readiness score: 80+ / 100
- ✅ Documentation: Complete
- ✅ Test coverage: Improved
- ✅ CI: All green
- ✅ No breaking changes

---

**End of Plan**
