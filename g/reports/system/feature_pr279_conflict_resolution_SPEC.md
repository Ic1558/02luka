# Feature SPEC: PR #279 Conflict Resolution

**Date:** 2025-11-15  
**Feature:** Resolve merge conflicts in PR #279  
**Branch:** `codex/fix-security-by-removing-auth-token-endpoint`  
**PR:** #279  
**Type:** Security / Conflict Resolution

---

## 1. Problem Statement

PR #279 (`codex/fix-security-by-removing-auth-token-endpoint`) has merge conflicts with `main` branch:

- **Conflicting File:** `g/apps/dashboard/wo_dashboard_server.js`
- **Conflict Type:** Both branches modified the same file
- **Current Status:** PR is CONFLICTING, cannot be merged

**Root Cause:**
- PR #279 branch: Contains security fixes (path traversal prevention, auth token removal, WO ID sanitization)
- Main branch: Has different version of the same file
- Both branches modified `wo_dashboard_server.js` independently

---

## 2. Goals

1. **Resolve merge conflicts** while preserving all security fixes from PR #279
2. **Ensure compatibility** with latest changes from main branch
3. **Maintain security improvements:**
   - Path traversal prevention (woStatePath, assertValidWoId, sanitizeWoId)
   - Auth token endpoint removal
   - State write canonicalization
4. **Make PR #279 mergeable** without breaking existing functionality

---

## 3. Scope

### ✅ Included
- Resolve conflicts in `g/apps/dashboard/wo_dashboard_server.js`
- Preserve all security fixes from PR #279 branch
- Integrate any valid changes from main branch
- Verify resolved code works correctly

### ❌ Excluded
- No new security features (only conflict resolution)
- No changes to other files (unless necessary for compatibility)
- No breaking changes to API contracts

---

## 4. Requirements

### 4.1 Conflict Resolution Requirements
- **MUST preserve:**
  - Security module imports (`./security/woId`)
  - Path traversal prevention logic
  - Auth token endpoint removal
  - WO ID sanitization
  - State canonicalization
  - All security-related functions

- **MUST integrate:**
  - Any bug fixes from main branch
  - Any non-conflicting improvements from main branch
  - Latest Redis configuration patterns (if different)

### 4.2 Code Quality Requirements
- No syntax errors
- All imports must resolve correctly
- Security functions must work as intended
- API endpoints must function correctly

### 4.3 Testing Requirements
- Resolved code must pass syntax check
- Security functions must be callable
- No broken imports or references

---

## 5. Key Differences Identified

### PR #279 Branch (Current)
- Uses `./security/woId` module (woStatePath, assertValidWoId, sanitizeWoId)
- Has `canonicalizeWoState()` function
- Auth token endpoint removed
- Security-focused comment: "SECURITY FIXED: Path traversal prevention + auth-token endpoint removed"

### Main Branch
- No security module imports
- May have `/api/auth-token` endpoint still present
- Different comment: "Fixed: Uses env vars for Redis password, includes /api/auth-token endpoint"

**Resolution Strategy:** Keep PR #279 security fixes, integrate any valid main branch changes that don't conflict.

---

## 6. Success Criteria

1. ✅ All merge conflicts resolved
2. ✅ All security fixes preserved
3. ✅ Code compiles without errors
4. ✅ No broken imports
5. ✅ PR #279 becomes mergeable
6. ✅ Security improvements remain intact

---

## 7. Clarifying Questions

**Q1:** Should we keep the `/api/auth-token` endpoint from main?  
**A:** No - PR #279 explicitly removes it for security. Keep the removal.

**Q2:** What if main has bug fixes we need?  
**A:** Integrate non-conflicting bug fixes while preserving security improvements.

**Q3:** Should we test the resolved code?  
**A:** Yes - at minimum syntax check and import verification.

**Q4:** What about other files that might conflict?  
**A:** Check all conflicting files, but focus on `wo_dashboard_server.js` first.

---

## 8. Assumptions

- PR #279 security fixes are correct and should be preserved
- Main branch may have some valid improvements to integrate
- Conflict resolution should prioritize security over convenience
- Resolved code will be tested before merge

---

## 9. Risks

- **Medium Risk:** Resolving conflicts incorrectly could break security fixes
- **Mitigation:** Careful line-by-line review, preserve all security code
- **Rollback:** Can revert conflict resolution if issues found

---

**Status:** ✅ SPEC Complete  
**Next:** Create PLAN.md with detailed resolution steps
