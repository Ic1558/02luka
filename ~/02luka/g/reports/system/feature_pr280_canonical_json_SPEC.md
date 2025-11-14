# Feature Specification: PR #280 - Canonical JSON for State Writes

**Date:** 2025-11-15  
**PR:** #280 - `fix(security): finish WO ID sanitization and canonicalize state writes`  
**Branch:** `codex/create-pr-to-fix-path-traversal-vulnerability-reknrb`  
**Status:** OPEN, MERGEABLE

---

## 1. Problem Statement

### Current Issue
Work Order (WO) state files and Redis payloads are written with non-deterministic JSON formatting:
- Object keys may appear in different orders
- Inconsistent formatting makes signature verification unreliable
- Future signing/verification logic cannot trust JSON structure

### Security Context
- PR #279 merged: Replay attack protection with signed requests
- PR #285 merged: Path traversal prevention and WO ID sanitization
- **Gap:** State writes are not canonicalized, making signatures unreliable

---

## 2. Goals

### Primary Goal
Introduce canonical JSON stringification so both dashboard servers write WO state files and Redis `wo:update` payloads with deterministic, sortable JSON that future signing/verification logic can trust.

### Secondary Goals
- Extend WO ID validation to mirrored `g/apps/dashboard/wo_dashboard_server.js`
- Ensure consistent validation/error handling across both dashboard servers
- Disable `/api/auth-token` endpoint in mirrored server

---

## 3. Requirements

### 3.1 Functional Requirements

**FR1: Canonical JSON Module**
- Create `server/security/canonicalJson.js` module
- Implement `canonicalJsonStringify(value, space)` function
- Sort object keys alphabetically
- Recursively canonicalize nested objects and arrays
- Skip `undefined` values
- Use consistent indentation (default: 2 spaces)

**FR2: Integration with Dashboard Servers**
- Use `canonicalJsonStringify` for all WO state file writes
- Use `canonicalJsonStringify` for Redis `wo:update` payloads
- Ensure both `apps/dashboard/wo_dashboard_server.js` and `g/apps/dashboard/wo_dashboard_server.js` use canonical JSON

**FR3: Security Consistency**
- Extend WO ID validation to mirrored dashboard server
- Disable `/api/auth-token` endpoint in mirrored server
- Ensure consistent error handling across both servers

### 3.2 Non-Functional Requirements

**NFR1: Performance**
- Canonicalization should not significantly impact write performance
- Recursive canonicalization should handle deep nesting efficiently

**NFR2: Compatibility**
- Must not break existing WO state file reads
- Must maintain backward compatibility with existing state files

**NFR3: Security**
- Canonical JSON must be deterministic for signature verification
- No information leakage through key ordering

---

## 4. Scope

### 4.1 Included

- ✅ New `server/security/canonicalJson.js` module (already implemented)
- ⏳ Integration with `apps/dashboard/wo_dashboard_server.js` (per PR description)
- ⏳ Integration with `g/apps/dashboard/wo_dashboard_server.js` (per PR description)
- ⏳ Security hardening of mirrored dashboard server (per PR description)

### 4.2 Excluded

- Major refactoring of dashboard server architecture
- Changes to WO state file schema
- Migration of existing state files to canonical format

---

## 5. Success Criteria

1. ✅ `canonicalJson.js` module exists and exports `canonicalJsonStringify`
2. ⏳ Both dashboard servers use `canonicalJsonStringify` for state writes
3. ⏳ Both dashboard servers use `canonicalJsonStringify` for Redis payloads
4. ⏳ Mirrored dashboard server has WO ID validation
5. ⏳ Mirrored dashboard server has `/api/auth-token` disabled
6. ⏳ All CI checks pass (currently `sandbox` check failing)

---

## 6. Clarifying Questions

1. **Q:** The PR diff only shows `canonicalJson.js` being added. Are the other changes (dashboard server integration) already in main?
   - **A:** Need to verify if changes to dashboard servers are already merged or need to be added

2. **Q:** Should existing WO state files be migrated to canonical format?
   - **A:** No - backward compatibility maintained, new writes will be canonical

3. **Q:** What about the `sandbox` CI failure?
   - **A:** Need to investigate and fix before merge

---

## 7. Assumptions

- Existing WO state file readers can handle canonical JSON (standard JSON, just sorted keys)
- Recursive canonicalization performance is acceptable for typical WO state sizes
- Both dashboard servers should have identical security posture

---

## 8. Dependencies

- PR #279 (merged) - Signed request verification
- PR #285 (merged) - WO ID sanitization and path traversal prevention
- `server/security/validateWoId.js` - WO ID validation functions

---

## 9. Risks

**Low Risk:**
- Canonical JSON is standard JSON with sorted keys - fully compatible
- Performance impact should be minimal

**Medium Risk:**
- Need to ensure both dashboard servers are updated consistently
- CI `sandbox` check failure needs investigation

---

**Status:** SPEC COMPLETE - Ready for PLAN development
