# PR #364 Conflict Analysis

**Date:** 2025-11-18  
**PR:** [#364 - feat(ci): bridge self-check aligned with Context Protocol v3.2](https://github.com/Ic1558/02luka/pull/364)  
**Status:** CONFLICTING (mergeStateStatus: DIRTY)

---

## Executive Summary

**Verdict:** ⚠️ **SIMPLE CONFLICT** — Duplicate governance comments and minor text difference

**Conflict Count:** 1 file, 1 conflict area
- `.github/workflows/bridge-selfcheck.yml` (content conflict)

**Resolution:** Accept PR #364 version (has complete Protocol v3.2 alignment)

---

## Conflict Details

### File: `.github/workflows/bridge-selfcheck.yml`

**Conflict Location:** Lines 287-291

**Conflict Type:** Content conflict (duplicate governance comments + text difference)

#### Main Branch (HEAD)

```yaml
# Governance: Aligned with Context Engineering Protocol v3.2
# - Critical issues → Mary/GC route to CLC (locked) or Gemini (non-locked)
# - Warnings → Mary/GC review, optional escalation
# - MLS logging follows Protocol v3.2 (tags include context-protocol-v3.2)
run-name: "Bridge Self-Check (${{ github.event_name }}): strict=${{ github.event.inputs.ci_strict || vars.CI_STRICT || '0' }}"

# ... later in file ...

          elif [[ "$STATUS" == "warning" || "$WARN" != "0" ]]; then
            {
              echo "ATTENTION → Mary/GC"
              echo "เหตุผล: พบ warnings ใน bridge/self-check (ไม่ถึง critical) ตาม Context Protocol v3.2"
```

#### PR #364 Branch

```yaml
---
name: Bridge Self-Check
run-name: "Bridge Self-Check (${{ github.event_name }}): strict=${{ github.event.inputs.ci_strict || vars.CI_STRICT || '0' }}"

# Governance: Aligned with Context Engineering Protocol v3.2
# - Critical issues → Mary/GC route to CLC (locked) or Gemini (non-locked)
# - Warnings → Mary/GC review, optional escalation
# - MLS logging follows Protocol v3.2 (tags include context-protocol-v3.2)
# Reference: g/docs/CONTEXT_ENGINEERING_PROTOCOL_v3.md

# ... later in file ...

          elif [[ "$STATUS" == "warning" || "$WARN" != "0" ]]; then
            {
              echo "ATTENTION → Mary/GC (for review)"
              echo "เหตุผล: พบ warnings ใน bridge/self-check (ไม่ถึง critical) ตาม Context Protocol v3.2"
```

#### Conflict Markers

```
<<<<<<< HEAD
              echo "ATTENTION → Mary/GC"
=======
              echo "ATTENTION → Mary/GC (for review)"
>>>>>>> pr-364
```

---

## Conflict Analysis

### Issue

**Problem:** 
1. Main branch already has governance comments at top (lines 3-6)
2. PR #364 adds same governance comments again (lines 5-9) with reference link
3. Warning message text differs: "ATTENTION → Mary/GC" vs "ATTENTION → Mary/GC (for review)"

**Root Cause:**
- Main branch was updated with Protocol v3.2 alignment (likely from another PR)
- PR #364 also adds Protocol v3.2 alignment (duplicate)
- Both branches have same intent but different text

### Resolution Strategy

**Accept PR #364 version because:**
1. ✅ Has reference link to Protocol document (more complete)
2. ✅ Warning message is more descriptive "(for review)"
3. ✅ Governance comments are in correct location (after `run-name`)
4. ✅ Maintains consistency with PR #364's intent

**Action:**
1. Remove duplicate governance comments from top (lines 3-6 in main)
2. Keep PR #364's governance comments (with reference link)
3. Accept PR #364's warning message text

---

## Resolution Steps

### Step 1: Resolve Conflict

**File:** `.github/workflows/bridge-selfcheck.yml`

**Action:** Accept PR #364 version

**Changes:**
1. Keep PR #364's governance comments (lines 5-9) with reference link
2. Remove duplicate governance comments from top (if any)
3. Accept PR #364's warning message: `"ATTENTION → Mary/GC (for review)"`

**Result:**
```yaml
---
name: Bridge Self-Check
run-name: "Bridge Self-Check (${{ github.event_name }}): strict=${{ github.event.inputs.ci_strict || vars.CI_STRICT || '0' }}"

# Governance: Aligned with Context Engineering Protocol v3.2
# - Critical issues → Mary/GC route to CLC (locked) or Gemini (non-locked)
# - Warnings → Mary/GC review, optional escalation
# - MLS logging follows Protocol v3.2 (tags include context-protocol-v3.2)
# Reference: g/docs/CONTEXT_ENGINEERING_PROTOCOL_v3.md

# ... rest of file ...

          elif [[ "$STATUS" == "warning" || "$WARN" != "0" ]]; then
            {
              echo "ATTENTION → Mary/GC (for review)"
              echo "เหตุผล: พบ warnings ใน bridge/self-check (ไม่ถึง critical) ตาม Context Protocol v3.2"
```

### Step 2: Verify Resolution

```bash
git diff --check .github/workflows/bridge-selfcheck.yml
# Should show no conflict markers
```

### Step 3: Test

- [ ] Verify workflow syntax is valid
- [ ] Check that governance comments are correct
- [ ] Verify warning message is descriptive
- [ ] Run CI checks

---

## Risk Assessment

### Low Risk

- **Conflict complexity:** Simple text difference
- **Resolution:** Straightforward (accept PR version)
- **Testing:** Workflow syntax validation only

### No Risk

- **Functionality:** No functional changes, only comments and text
- **Breaking changes:** None

---

## Additional Issues

### Path Guard Violation

**Issue:** PR #364 includes report file in wrong location:
- `g/reports/feature_bridge_selfcheck_protocol_v3_alignment_PLAN.md`

**Path Guard Requirement:** Reports must be in `g/reports/system/` or subdirectories

**Action Required:**
- Move file to `g/reports/system/feature_bridge_selfcheck_protocol_v3_alignment_PLAN.md`
- Or remove if not needed in PR

### Trailing Whitespace

**Issue:** Report file has trailing whitespace (lines 3-6, 312)

**Action Required:**
- Remove trailing whitespace from report file

---

## Recommendations

### Immediate Actions

1. **Resolve conflict** — Accept PR #364 version
2. **Fix Path Guard violation** — Move report file to `g/reports/system/`
3. **Fix trailing whitespace** — Clean up report file
4. **Test workflow** — Verify syntax is valid

### Before Merge

- [ ] Conflict resolved
- [ ] Path Guard violation fixed
- [ ] Trailing whitespace removed
- [ ] Workflow syntax validated
- [ ] CI checks pass

---

## Current PR Status

**Status:** OPEN, CONFLICTING  
**CI Checks:** ⚠️ Path Guard failing (report file location)  
**Merge State:** DIRTY  
**Files Changed:** 2 files
- `.github/workflows/bridge-selfcheck.yml` (conflict)
- `g/reports/feature_bridge_selfcheck_protocol_v3_alignment_PLAN.md` (Path Guard violation)

---

## Next Steps

1. ⚠️ Resolve merge conflict (accept PR #364 version)
2. ⚠️ Fix Path Guard violation (move report file)
3. ⚠️ Fix trailing whitespace
4. ⏳ Re-run CI checks
5. ⏳ Ready for merge

---

**Analysis Date:** 2025-11-18  
**Status:** ⚠️ Simple conflict, easy to resolve
