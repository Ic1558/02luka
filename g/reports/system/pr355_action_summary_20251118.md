# PR #355 Action Summary & Next Steps

**Date:** 2025-11-18  
**PR:** [#355 - LaunchAgent Validator](https://github.com/Icmini/02luka/pull/355)  
**Status:** BLOCKING — Requires fixes before merge

---

## Current Status

**PR Details:**
- State: OPEN
- Mergeable: CONFLICTING
- Merge State: DIRTY
- Head: `feature/launchagent-validator`
- Base: `main`

**Blocking Issues:**
1. ⚠️ Merge conflicts: 3 files
2. ⚠️ Path Guard violations: Files in wrong locations
3. ⚠️ Large PR: 217 files

---

## Issue Analysis

### 1. Path Guard Violations

**Files in Wrong Locations:**
- `g/reports/feature_agents_layout_*.md` (2 files) → Should be in `g/reports/system/`
- `g/reports/mcp_health/*.md` (many files) → Should be in `g/reports/system/mcp_health/`
- `g/reports/sessions/*.md` (many files) → Should be in `g/reports/system/sessions/` or `g/reports/sessions/` (if sessions is allowed)
- `g/reports/gh_failures/.seen_runs` → Should be in `g/reports/system/gh_failures/`

**Total Violating Files:** ~13 files in root, plus subdirectories that may need to be under `system/`

### 2. Merge Conflicts

**Conflicted Files:**
1. `apps/dashboard/dashboard.js` - Content conflict (main has v2.2.0)
2. `apps/dashboard/index.html` - Content conflict
3. `tools/validate_launchagents.zsh` - Add/add conflict (both branches added it)

---

## Fix Strategy

### Phase 1: Path Guard Fixes

**Step 1: Move Root-Level Files**
```bash
git checkout feature/launchagent-validator
git mv g/reports/feature_agents_layout_*.md g/reports/system/
```

**Step 2: Move Subdirectories**
```bash
# Move mcp_health to system/
git mv g/reports/mcp_health g/reports/system/mcp_health

# Move sessions (if needed)
# Note: Check Path Guard rules - sessions/ might be allowed
```

**Step 3: Move Other Files**
```bash
git mv g/reports/gh_failures g/reports/system/gh_failures
```

### Phase 2: Conflict Resolution

**Step 1: Merge Main**
```bash
git fetch origin main
git merge origin/main
```

**Step 2: Resolve Conflicts**
- Dashboard files: Accept main version (PR doesn't modify dashboard)
- Validator script: Merge both versions, keep best implementation

**Step 3: Test**
- Verify validator works
- Verify dashboard works
- Run Path Guard check

---

## Execution Plan

### Option A: Fix in PR Branch (Recommended)

**Steps:**
1. Checkout PR branch
2. Fix Path Guard violations
3. Resolve conflicts
4. Commit fixes
5. Push to PR branch

**Pros:**
- Fixes applied directly to PR
- CI will verify fixes
- Clear history

**Cons:**
- Requires write access to PR branch
- May need force push if rebase

### Option B: Create Fix PR

**Steps:**
1. Create new branch from PR branch
2. Apply fixes
3. Create new PR targeting PR #355 branch
4. Merge fix PR into PR #355

**Pros:**
- No force push needed
- Can review fixes separately

**Cons:**
- More complex workflow
- Requires two PRs

---

## Recommended Approach

**Use Option A** (Fix in PR Branch):

1. **Checkout PR Branch:**
   ```bash
   git fetch origin feature/launchagent-validator
   git checkout feature/launchagent-validator
   ```

2. **Fix Path Guard:**
   ```bash
   # Move root files
   git mv g/reports/feature_agents_layout_*.md g/reports/system/
   
   # Move subdirectories
   git mv g/reports/mcp_health g/reports/system/mcp_health
   git mv g/reports/gh_failures g/reports/system/gh_failures
   
   # Commit
   git commit -m "fix(path-guard): move report files to g/reports/system/ subdirectories"
   ```

3. **Resolve Conflicts:**
   ```bash
   git fetch origin main
   git merge origin/main
   
   # Resolve conflicts:
   # - Accept main for dashboard files
   # - Merge validator script
   
   git commit -m "fix(merge): resolve conflicts with main"
   ```

4. **Push:**
   ```bash
   git push origin feature/launchagent-validator
   ```

---

## Verification Steps

After fixes:

1. **Check Path Guard:**
   ```bash
   gh pr checks 355 | grep -i "path"
   ```

2. **Check Conflicts:**
   ```bash
   gh pr view 355 --json mergeable,mergeStateStatus
   ```

3. **Verify Files:**
   ```bash
   gh pr diff 355 --name-only | grep "^g/reports/" | grep -v "/system/"
   # Should return empty (no violations)
   ```

---

## Risk Assessment

**Low Risk:**
- Path Guard fixes (file moves, straightforward)
- Dashboard conflict resolution (accept main)

**Medium Risk:**
- Validator script merge (need to compare both versions)
- Large number of files to move

**Mitigation:**
- Test after each phase
- Verify Path Guard passes
- Test validator script works

---

## Next Steps

**Ready to Execute:** ✅ Yes

**Action Required:**
1. ⏳ Fix Path Guard violations
2. ⏳ Resolve merge conflicts
3. ⏳ Test and verify
4. ⏳ Push fixes
5. ⏳ Verify CI passes

---

## Notes

- PR #355 core feature (validator) is well-implemented
- Issues are fixable (Path Guard + conflicts)
- Estimated time: 1-2 hours
- After fixes, PR should be ready for merge

---

**Status:** Ready for execution  
**Confidence:** High  
**Risk:** Low-Medium
