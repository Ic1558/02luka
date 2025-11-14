# Code Review: PR #280 - Canonical JSON for State Writes

**Date:** 2025-11-15  
**PR:** #280 - `fix(security): finish WO ID sanitization and canonicalize state writes`  
**Reviewer:** CLS  
**Status:** ⚠️ **CONDITIONAL APPROVAL** - CI failure needs investigation

---

## 1. Style Check

### ✅ Code Quality
- **File:** `server/security/canonicalJson.js`
- **Lines:** 27
- **Formatting:** Consistent, clean
- **Naming:** Clear and descriptive
- **Comments:** None (self-documenting code)

### ✅ Best Practices
- Uses `Object.prototype.toString.call()` for reliable type checking
- Recursive implementation handles nested structures
- Skips `undefined` values appropriately
- Exports only what's needed

---

## 2. History-Aware Review

### Context
- **PR #279 (merged):** Added signed request verification
- **PR #285 (merged):** Added WO ID sanitization and path traversal prevention
- **This PR:** Adds canonical JSON for reliable signature verification

### Related Changes
- Previous security fixes focused on input validation
- This PR focuses on output consistency for signature verification
- Aligns with security hardening strategy

---

## 3. Obvious-Bug Scan

### ✅ No Obvious Bugs Found
- Type checking is robust (`isPlainObject` correctly identifies plain objects)
- Recursive canonicalization handles all data types
- `undefined` values are skipped (prevents JSON.stringify issues)
- Key sorting is deterministic (alphabetical)

### ⚠️ Potential Edge Cases
1. **Circular References:** Not handled (would cause stack overflow)
   - **Risk:** Low (WO state objects shouldn't have circular refs)
   - **Mitigation:** Acceptable for current use case

2. **Very Deep Nesting:** Could cause stack overflow
   - **Risk:** Low (WO state objects are typically shallow)
   - **Mitigation:** Acceptable for current use case

3. **Large Objects:** Performance impact
   - **Risk:** Low (WO state objects are typically small)
   - **Mitigation:** Acceptable for current use case

---

## 4. Risk Summary

### ✅ Low Risk
- **Compatibility:** Canonical JSON is standard JSON with sorted keys - fully compatible
- **Performance:** Minimal impact for typical WO state sizes
- **Security:** No new attack vectors introduced

### ⚠️ Medium Risk
- **CI Failure:** `sandbox` check is failing - needs investigation
- **Integration:** PR description mentions dashboard server changes, but diff only shows `canonicalJson.js`
- **Completeness:** Need to verify if dashboard server integration is already done or missing

---

## 5. Diff Hotspots

### New File: `server/security/canonicalJson.js`

**Lines 1-3: Type Checking**
```javascript
const isPlainObject = (value) => {
  return Object.prototype.toString.call(value) === "[object Object]";
};
```
- ✅ Robust type checking (handles edge cases better than `typeof` or `instanceof`)
- ✅ Correctly distinguishes plain objects from arrays, Date, etc.

**Lines 5-21: Recursive Canonicalization**
```javascript
function canonicalize(value) {
  if (Array.isArray(value)) {
    return value.map((item) => canonicalize(item));
  }
  if (isPlainObject(value)) {
    const result = {};
    for (const key of Object.keys(value).sort()) {
      const canonicalValue = canonicalize(value[key]);
      if (canonicalValue === undefined) {
        continue;
      }
      result[key] = canonicalValue;
    }
    return result;
  }
  return value;
}
```
- ✅ Handles arrays, objects, and primitives correctly
- ✅ Key sorting ensures deterministic output
- ✅ Skips `undefined` values (prevents JSON.stringify issues)
- ✅ Recursive implementation handles nested structures

**Lines 23-25: JSON Stringification**
```javascript
function canonicalJsonStringify(value, space = 2) {
  return JSON.stringify(canonicalize(value), null, space);
}
```
- ✅ Simple wrapper around standard JSON.stringify
- ✅ Default 2-space indentation matches existing code style
- ✅ Clean API

---

## 6. Missing Integration (Per PR Description)

### ⚠️ Gap Identified
PR description states:
- "extend the new work-order ID validator and normalized path resolution to the mirrored `g/apps/dashboard/wo_dashboard_server.js`"
- "introduce `server/security/canonicalJson.js` so both dashboard servers write WO state files and Redis `wo:update` payloads with canonical JSON"

**Current Diff:**
- ✅ `canonicalJson.js` added
- ❓ Dashboard server integration not visible in diff

**Action Required:**
- Verify if dashboard server changes are already in main
- If missing, add integration before merge

---

## 7. CI Status

### ⚠️ Sandbox Check Failing
- **Check:** `sandbox` (4s)
- **Status:** FAIL
- **Action:** Need to investigate what's causing the failure
- **Impact:** Blocks merge (should be fixed)

### ✅ Other Checks Passing
- Code Quality Checks: ✅ PASS
- Path Guard: ✅ PASS
- Integration Tests: ✅ PASS
- All other checks: ✅ PASS

---

## 8. Recommendations

### Before Merge
1. **Investigate CI Failure**
   - Check sandbox check logs
   - Fix any banned command patterns
   - Re-run checks

2. **Verify Dashboard Server Integration**
   - Confirm if changes are already in main
   - If missing, add integration
   - Ensure both servers use canonical JSON

3. **Add Tests** (Optional but Recommended)
   - Unit tests for `canonicalJsonStringify`
   - Integration tests for state file writes
   - Verify canonical format in Redis payloads

### After Merge
1. **Monitor**
   - Watch for any issues with state file reads
   - Verify signature verification works with canonical JSON
   - Check performance impact

---

## 9. Final Verdict

### ⚠️ **CONDITIONAL APPROVAL**

**Reasons:**
- ✅ Code quality is good
- ✅ Implementation is correct
- ✅ No obvious bugs
- ⚠️ CI `sandbox` check failing (needs investigation)
- ⚠️ Dashboard server integration unclear (needs verification)

**Conditions for Full Approval:**
1. Fix CI `sandbox` check failure
2. Verify dashboard server integration is complete (or add if missing)
3. All CI checks passing

**Recommendation:**
- Investigate and fix CI failure
- Verify completeness of changes
- Then merge

---

**Status:** ⚠️ **CONDITIONAL APPROVAL** - Fix CI and verify integration before merge
