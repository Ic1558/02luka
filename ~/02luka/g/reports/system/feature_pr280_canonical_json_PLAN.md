# Feature Plan: PR #280 - Canonical JSON for State Writes

**Date:** 2025-11-15  
**PR:** #280 - `fix(security): finish WO ID sanitization and canonicalize state writes`  
**Status:** OPEN, MERGEABLE (UNSTABLE - sandbox CI failing)

---

## 1. Overview

This plan outlines the steps to complete PR #280, which introduces canonical JSON stringification for WO state files and Redis payloads, and extends security fixes to the mirrored dashboard server.

---

## 2. Current State Analysis

### ✅ Completed
- `server/security/canonicalJson.js` module created
- Module implements `canonicalJsonStringify` with key sorting

### ⏳ Pending (per PR description)
- Integration with `apps/dashboard/wo_dashboard_server.js`
- Integration with `g/apps/dashboard/wo_dashboard_server.js`
- Security hardening of mirrored dashboard server
- Fix CI `sandbox` check failure

### 🔍 Investigation Needed
- Verify if dashboard server changes are already in main
- Check what's causing `sandbox` CI failure
- Confirm what changes are actually needed

---

## 3. Phases

### Phase 1: Investigation & Verification (15 minutes)

**Tasks:**
1. **Verify Current State**
   - Check if dashboard server changes are already merged in main
   - Compare `apps/dashboard/wo_dashboard_server.js` in branch vs main
   - Compare `g/apps/dashboard/wo_dashboard_server.js` in branch vs main

2. **Investigate CI Failure**
   - Check `sandbox` CI check logs
   - Identify what's causing the failure
   - Determine if it's related to this PR or pre-existing

3. **Review PR Description vs Actual Changes**
   - Confirm what changes are actually in the PR
   - Identify any missing changes mentioned in PR description

**Deliverables:**
- Status report of what's actually changed
- CI failure analysis
- Gap analysis (what's missing vs PR description)

---

### Phase 2: Complete Missing Changes (if needed) (30 minutes)

**If dashboard server integration is missing:**

1. **Update `apps/dashboard/wo_dashboard_server.js`**
   - Import `canonicalJsonStringify` from `server/security/canonicalJson.js`
   - Replace `JSON.stringify` with `canonicalJsonStringify` in `writeStateFile`
   - Replace `JSON.stringify` with `canonicalJsonStringify` in Redis publish
   - Ensure WO ID validation is present
   - Ensure `/api/auth-token` endpoint is disabled

2. **Update `g/apps/dashboard/wo_dashboard_server.js`**
   - Same changes as above
   - Ensure consistency with main dashboard server

3. **Verify Security Consistency**
   - Both servers use same WO ID validation
   - Both servers have `/api/auth-token` disabled
   - Both servers use canonical JSON

**Deliverables:**
- Updated dashboard server files
- Verification that both servers are consistent

---

### Phase 3: Fix CI Issues (15 minutes)

**Tasks:**
1. **Fix Sandbox Check**
   - Review sandbox check failure
   - Identify banned command patterns
   - Fix or exclude as appropriate

2. **Re-run CI Checks**
   - Verify all checks pass
   - Confirm PR is ready for merge

**Deliverables:**
- All CI checks passing
- PR status: MERGEABLE, STABLE

---

### Phase 4: Testing & Verification (20 minutes)

**Tasks:**
1. **Manual Testing**
   - Test WO state file writes (verify canonical format)
   - Test Redis payloads (verify canonical format)
   - Test WO ID validation
   - Test `/api/auth-token` endpoint (should be disabled)

2. **Code Review**
   - Review canonical JSON implementation
   - Verify security consistency
   - Check error handling

**Deliverables:**
- Test results
- Code review report
- Ready for merge confirmation

---

## 4. Test Strategy

### Unit Tests
- Test `canonicalJsonStringify` with various inputs:
  - Simple objects
  - Nested objects
  - Arrays
  - Mixed structures
  - Edge cases (empty, null, undefined)

### Integration Tests
- Test WO state file writes produce canonical JSON
- Test Redis payloads are canonical
- Test both dashboard servers behave consistently

### Security Tests
- Verify WO ID validation works
- Verify `/api/auth-token` returns 404
- Verify path traversal protection active

---

## 5. Rollback Plan

If issues arise after merge:
1. Revert commit on main
2. Restore previous dashboard server versions
3. Remove `canonicalJson.js` if needed

---

## 6. Timeline Estimate

- **Phase 1 (Investigation):** 15 minutes
- **Phase 2 (Complete Changes):** 30 minutes (if needed)
- **Phase 3 (Fix CI):** 15 minutes
- **Phase 4 (Testing):** 20 minutes
- **Total:** ~80 minutes (if all phases needed)

---

## 7. Next Steps

1. ⏳ **Start with Phase 1** - Investigate current state
2. ⏳ **Determine what's actually missing** - Compare PR description vs actual changes
3. ⏳ **Fix CI issues** - Resolve sandbox check failure
4. ⏳ **Complete integration** - If dashboard server changes are missing
5. ⏳ **Test and verify** - Ensure everything works
6. ⏳ **Merge PR** - When ready

---

**Status:** PLAN COMPLETE - Ready for execution
