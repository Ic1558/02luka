# Code Review: GitHub Actions Cancellation vs File Structure Reorganization

**Review Date:** 2025-11-12  
**Reviewer:** CLS (Cognitive Local System Orchestrator)  
**Scope:** Analysis of whether file structure reorganization caused workflow cancellations

---

## Executive Summary

**Verdict:** ⚠️ **PARTIALLY RELATED** - File structure reorganization may contribute to cancellations, but not the primary cause

**Key Finding:** File structure reorganization introduced path-based workflow triggers that may cause unexpected cancellations when paths don't match, but the main cancellation causes are still concurrency settings and timeouts.

---

## Analysis

### 1. File Structure Reorganization Impact

**What Changed:**
- Reports moved from `g/reports/*.md` to `g/reports/{phase5_governance,phase6_paula,system}/*.md`
- Path guard added to `ci.yml` to enforce new structure
- Migration script created (`tools/fsorg_migrate.zsh`)

**Workflow Impact:**

#### ✅ Path Guard in CI (`ci.yml` lines 51-76)
```yaml
path_guard:
  name: Path Guard (Reports)
  runs-on: ubuntu-latest
  if: github.event_name == 'pull_request'
  steps:
    - name: Check report paths
      run: |
        BAD=$(git diff --name-only origin/main...HEAD | grep -E '^g/reports/[^/]+\.md$' || true)
        if [ -n "$BAD" ]; then
          echo "❌ Reports must be in g/reports/{phase5_governance,phase6_paula,system}/ only"
          exit 1
        fi
```

**Impact:** This job will **FAIL** if PRs have reports in wrong location, causing workflow to fail (not cancel).

#### ⚠️ Workflows with Path Triggers

**Workflows that may be affected:**

1. **`daily-proof.yml`** (line 16):
   ```yaml
   paths:
     - 'g/reports/**'
   ```
   - ✅ Still works (matches all subdirectories)

2. **`health-dashboard-guard.yml`** (line 7):
   ```yaml
   paths:
     - 'g/reports/health_dashboard.json'
   ```
   - ✅ Still works (specific file, not moved)

3. **Other workflows:**
   - Most workflows use `tools/**`, `config/**` (not affected)
   - No workflows explicitly check for `g/reports/*.md` at root level

**Conclusion:** Path triggers should still work correctly.

---

### 2. Cancellation Causes Analysis

**Primary Causes (from SPEC):**
1. **Concurrency Settings:** `cancel-in-progress: true` (most workflows)
2. **Timeouts:** Varying timeout settings (2-30 minutes)
3. **Cascading Failures:** Dependent job failures
4. **Manual Cancellations:** User-initiated

**Structure Reorganization Impact:**
- **Low:** Path guard failures cause workflow **failures**, not cancellations
- **Medium:** If path guard fails, dependent jobs may be cancelled
- **Low:** Path triggers should still match correctly

---

### 3. Potential Issues

#### Issue 1: Path Guard May Cause Cascading Cancellations ⚠️

**Scenario:**
1. PR has report in wrong location (`g/reports/feature_xyz.md`)
2. Path guard job fails
3. Dependent jobs may be cancelled (if `needs: path_guard`)

**Current State:**
- `path_guard` is standalone (no `needs:` dependencies)
- Other jobs don't depend on it
- **Impact:** Low - path guard failure doesn't cancel other jobs

#### Issue 2: Workflow Path Triggers May Not Match ⚠️

**Scenario:**
- Old workflows may have `paths: ['g/reports/*.md']` (root level)
- After reorganization, files are in subdirectories
- Workflows may not trigger on report changes

**Current State:**
- No workflows found with `paths: ['g/reports/*.md']` (root level)
- All workflows use `g/reports/**` or specific files
- **Impact:** Low - no evidence of this issue

#### Issue 3: Migration May Have Broken Paths ⚠️

**Scenario:**
- Files moved but workflows not updated
- Hard-coded paths in scripts may be broken

**Current State:**
- Migration uses `git mv` (preserves history)
- Path guard enforces new structure
- **Impact:** Low - migration is reversible

---

## Root Cause Assessment

### Is Structure Reorganization the Primary Cause?

**Answer:** ⚠️ **PARTIALLY** - It may contribute but is not the main cause

**Evidence:**
1. ✅ Path guard failures cause **failures**, not cancellations
2. ✅ Most cancellations are from `cancel-in-progress: true` (concurrency)
3. ⚠️ Path guard failures may cause dependent jobs to be cancelled
4. ⚠️ If workflows don't trigger due to path mismatches, runs may be cancelled

**Recommendation:**
- Structure reorganization is a **contributing factor**, not the root cause
- Main causes are still concurrency settings and timeouts
- Should fix both: cancellation management AND verify path triggers

---

## Recommendations

### Must Fix (High Priority)

1. **Verify Path Triggers Work:**
   - Test that workflows trigger on report changes in new structure
   - Update any workflows with hard-coded paths
   - Document path trigger patterns

2. **Review Path Guard Impact:**
   - Ensure path guard failures don't cancel other jobs
   - Add `continue-on-error: true` if needed
   - Document path guard behavior

### Should Fix (Medium Priority)

3. **Update Workflow Documentation:**
   - Document new report structure in workflow comments
   - Add examples of correct paths
   - Update troubleshooting guides

4. **Add Path Validation:**
   - Pre-commit hook to check report paths
   - CI check to verify structure
   - Prevent wrong paths before PR

### Nice to Have (Low Priority)

5. **Migration Verification:**
   - Verify all workflows still trigger correctly
   - Test path guard with various scenarios
   - Document migration impact

---

## Testing Recommendations

### Test 1: Path Guard Behavior
```bash
# Create PR with report in wrong location
echo "# Test" > g/reports/test.md
git add g/reports/test.md
git commit -m "test: wrong path"
# Push PR and verify path_guard fails but doesn't cancel other jobs
```

### Test 2: Workflow Path Triggers
```bash
# Create report in new structure
echo "# Test" > g/reports/system/test.md
git add g/reports/system/test.md
git commit -m "test: correct path"
# Push and verify workflows trigger
```

### Test 3: Concurrency Cancellation
```bash
# Push multiple commits quickly
git commit --allow-empty -m "test 1"
git push
git commit --allow-empty -m "test 2"
git push
# Verify first run is cancelled (expected behavior)
```

---

## Final Verdict

**✅/⚠️ MIXED** - Structure reorganization may contribute to cancellations, but primary causes are still concurrency settings and timeouts.

**Reasoning:**
1. Path guard failures cause failures, not cancellations (directly)
2. Most cancellations are from `cancel-in-progress: true` (concurrency)
3. Path mismatches may prevent workflows from triggering (indirect cancellation)
4. Should address both: cancellation management AND path trigger verification

**Action Items:**
1. ✅ Proceed with cancellation fix feature (addresses primary causes)
2. ⚠️ Verify path triggers work with new structure (addresses contributing factor)
3. ⚠️ Document path guard behavior (prevents confusion)

---

**Reviewer:** CLS  
**Date:** 2025-11-12  
**Next Steps:** Verify path triggers, then proceed with cancellation fix
