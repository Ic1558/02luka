# PR Queue Clearance - Action Plan

**Date:** 2025-11-18  
**Status:** 📋 **EXECUTABLE PLAN**  
**Based on:** Current PR status assessment

---

## Executive Summary

**Reality Check:**
- ✅ PR #359, #360, #361, #363 already merged
- ✅ Mary dispatcher uses `grep` (no PyYAML dependency) - Good!
- ⚠️ Need to verify LPE ACL security
- ⚠️ Need to verify MLS schema
- 🔴 PR #358, #368 have conflicts

**Focus:** Verify merged PRs didn't introduce regressions, then fix conflicts

---

## Phase 1: Verification (Critical)

### ✅ Step 1.1 - Verify Mary Dispatcher

**Status:** ✅ **VERIFIED - No PyYAML Dependency**

**Finding:**
- `tools/watchers/mary_dispatcher.zsh` uses `grep` for YAML parsing
- No Python/YAML dependencies
- Simple, robust implementation

**Action:** None needed - already safe

---

### ⚠️ Step 1.2 - Verify LPE Path ACL Security

**Status:** ⚠️ **NEEDS VERIFICATION**

**Action:**
1. Find LPE worker file(s) on main
2. Check for path ACL checks
3. Verify allow list enforcement
4. Document findings

**Files to Check:**
- LPE worker script (location TBD)
- LaunchAgent plist (if exists)
- Any patch application logic

**If ACL Missing:**
- Create hotfix PR to restore ACL
- Priority: CRITICAL (security)

---

### ⚠️ Step 1.3 - Verify MLS Ledger Schema

**Status:** ⚠️ **NEEDS VERIFICATION**

**Current Schema (from `mls_lessons.jsonl`):**
```json
{
  "id": "MLS-1762282996",
  "type": "solution",
  "title": "...",
  "description": "..."
}
```

**Action:**
1. Check any MLS append/write scripts
2. Verify they match this format
3. Check for schema versioning

**Files to Check:**
- Any `append_mls*.py` scripts
- MLS report generators
- Dashboard MLS readers

---

## Phase 2: Fix Conflicts

### 🔴 Step 2.1 - Fix PR #358

**Status:** CONFLICTING/DIRTY, 100 files

**Action Plan:**
1. **Check conflicts:**
   ```bash
   git fetch origin
   git checkout <pr358-branch>
   git merge origin/main --no-commit
   ```

2. **Remove noise:**
   - Remove `g/reports/mcp_health/*`
   - Remove session logs
   - Remove generated files

3. **Resolve conflicts:**
   - Use main as base for core files
   - Cherry-pick only new logic

4. **Test & push:**
   - Run CI
   - Push rebased branch

---

### 🔴 Step 2.2 - Fix PR #368 (Our Dashboard PR)

**Status:** CONFLICTING/DIRTY, 10 files

**Action Plan:**
1. **Rebase on main:**
   ```bash
   git checkout feat/pr298-complete-migration
   git fetch origin main
   git rebase origin/main
   ```

2. **Resolve conflicts:**
   - Dashboard files likely conflict
   - Keep our pipeline metrics additions
   - Merge main's changes

3. **Test:**
   - Verify dashboard works
   - Check metrics display

4. **Push:**
   ```bash
   git push --force-with-lease origin feat/pr298-complete-migration
   ```

---

## Phase 3: Other Open PRs

### Dashboard Timeline PRs (Multiple)

**PRs:** #310, #328, #336, #345, #349

**Status:** All CONFLICTING/DIRTY

**Observation:** Multiple PRs for same feature (WO timeline)

**Action:**
1. Identify which PR has most complete implementation
2. Close duplicates
3. Fix conflicts in chosen PR
4. Merge one canonical version

---

## Immediate Next Steps

### Priority 1: Security Verification

1. **Find and verify LPE worker:**
   ```bash
   find . -name "*lpe*worker*" -o -name "*lpe*apply*"
   ```

2. **Check for ACL:**
   - Search for `path_acl`, `allow_list`, `BASE` checks
   - Verify patch validation

3. **Document findings**

### Priority 2: Fix Our PR (#368)

1. Rebase on main
2. Resolve conflicts
3. Test dashboard
4. Push updated branch

### Priority 3: Fix PR #358

1. Check conflicts
2. Remove noise
3. Resolve conflicts
4. Rebase

---

## Verification Checklist

### Before Considering Queue "Clear":

- [ ] LPE ACL verified (or hotfix created)
- [ ] MLS schema verified (or fixed)
- [ ] PR #368 conflicts resolved
- [ ] PR #358 conflicts resolved
- [ ] Dashboard timeline PRs deduplicated
- [ ] All critical security checks pass

---

## Status Summary

**Completed:**
- ✅ PR #359, #360, #361, #363 merged
- ✅ Mary dispatcher verified (no PyYAML)

**Pending:**
- ⚠️ LPE ACL verification
- ⚠️ MLS schema verification
- 🔴 PR #368 conflicts
- 🔴 PR #358 conflicts
- 🔴 Dashboard timeline PR deduplication

**Next Action:** Find LPE worker and verify ACL

---

**Created:** 2025-11-18  
**Status:** Ready for execution

