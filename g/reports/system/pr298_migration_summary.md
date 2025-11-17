# PR #298 Migration Summary & Action Plan

**Date:** 2025-11-18  
**Status:** READY FOR EXECUTION

---

## Executive Summary

**Decision:** PR #298 should NOT be merged directly. Create new PR from `main` instead.

**Reason:** PR #298 conflicts with `main` (SOT) which has advanced dashboard v2.2.0. Merging would regress current features.

**Action:** Migrate useful features from PR #298 to new branch based on `main`.

---

## Current Status

### PR #298
- **Status:** CONFLICTING (8 files)
- **Action:** Close as "superseded"
- **Reason:** Based on old dashboard version, conflicts with SOT

### PR #366
- **Status:** ✅ MERGED
- **Note:** SOT corrections completed

### PR #367
- **Status:** ✅ READY FOR REVIEW/MERGE
- **Files:** 2 files (clean)
- **Note:** Protocol v3.2 schema updates

---

## Migration Strategy

### Phase 1: Close Old PR
1. Comment on PR #298: "Superseded by new PR based on main (dashboard v2.2.0 as SOT)"
2. Close PR #298

### Phase 2: Create New Branch
```bash
git checkout main
git pull origin main
git checkout -b feat/dashboard-followup-v2
```

### Phase 3: Extract & Integrate Features
Use the migration prompt (`pr298_migration_prompt.md`) to:
1. Extract useful features from PR #298
2. Integrate into `main` dashboard v2.2.0
3. Preserve all existing functionality
4. Maintain Protocol v3.2 compliance

### Phase 4: Test & Verify
1. Manual dashboard QA
2. CI checks
3. Protocol compliance verification

### Phase 5: Create New PR
- Title: `feat(dashboard): merge PR298 features onto v2.2.0 SOT`
- Description: See migration prompt
- Link to PR #298 as "superseded"

---

## Files to Handle

### Critical (High Priority)
1. **`g/apps/dashboard/dashboard.js`**
   - Use `main` version as SOT
   - Add PR #298 features on top
   - Preserve: metrics, reality, services, MLS, bulletproof delegation

2. **`docs/GG_ORCHESTRATOR_CONTRACT.md`**
   - Use `main` version (Protocol v3.2) as base
   - Merge only non-conflicting additions

### Medium Priority
3. **`g/apps/dashboard/data/followup.json`**
   - Use `main` structure as base
   - Add PR #298 fields to items array

4. **Documentation files**
   - Merge content from both versions
   - Remove duplicates

---

## Migration Prompt

**Location:** `g/reports/system/pr298_migration_prompt.md`

**Usage:** Copy entire prompt to Liam/Gemini in Cursor to execute migration.

---

## Success Criteria

✅ Dashboard v2.2.0 features preserved  
✅ PR #298 features integrated  
✅ No conflicts with `main`  
✅ Protocol v3.2 compliance maintained  
✅ All tests pass

---

## Next Steps

1. ✅ Analysis complete
2. ✅ Migration prompt created
3. ⏳ Execute migration (use prompt with Liam/Gemini)
4. ⏳ Test and verify
5. ⏳ Create new PR
6. ⏳ Close PR #298

---

## References

- PR #298: https://github.com/Ic1558/02luka/pull/298
- PR #366: Merged (SOT corrections)
- PR #367: Ready for review/merge
- Migration Prompt: `g/reports/system/pr298_migration_prompt.md`
- Conflict Analysis: `g/reports/system/pr298_conflict_analysis_20251118.md`
