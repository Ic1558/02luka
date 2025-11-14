# PR Conflict Resolution Guide

**Generated:** November 4, 2025
**Status:** 4 branches with conflicts identified and resolution provided

---

## Overview

Analysis of 193 branches found 4 branches with merge conflicts when attempting to merge into main. All 4 branches are variants of the same feature (user authentication) and have identical conflicts.

## Conflicting Branches

1. `codex/add-user-authentication-feature`
2. `codex/add-user-authentication-feature-hhs830`
3. `codex/add-user-authentication-feature-not1zo`
4. `codex/add-user-authentication-feature-yiytty`

## Root Cause Analysis

### Architectural Change

The conflicts stem from a fundamental architectural change in the main branch:

**Before (branch state):**
- `boss-api/server.cjs` existed and provided HTTP API endpoints
- `scripts/smoke.sh` tested the boss-api HTTP endpoints
- Authentication feature was being added to this API

**After (main branch):**
- `boss-api/server.cjs` was removed entirely
- `scripts/smoke.sh` was rewritten to test system structure instead
- New architecture doesn't use the old boss-api approach

### Specific Conflicts

#### 1. `boss-api/server.cjs` - MODIFY/DELETE Conflict

```
Status: DELETED in main, MODIFIED in branch
Reason: Architecture changed, file no longer needed
Resolution: Accept deletion (remove file)
```

The file was completely removed from main because the boss-api architecture was superseded.

#### 2. `scripts/smoke.sh` - ADD/ADD Conflict

**Branch version** (lines 1-30):
```bash
#!/usr/bin/env bash
# Tests boss-api HTTP endpoints
PORT="${PORT:-4000}"
BASE_URL="${BASE_URL:-http://127.0.0.1:${PORT}}"

# Tests /healthz, /api/jobs, /api/status, /status
```

**Main version** (lines 32-85):
```bash
#!/bin/bash
# Smoke tests for 02LUKA system
# Tests: Directory structure, CLS integration, Workflows, Git health, Scripts
```

**Resolution:** Accept main's version - it tests the current system architecture.

---

## Resolution Strategy

### Option 1: Automated Resolution (Recommended)

Use the provided automated script:

```bash
chmod +x resolve_pr_conflicts.sh
./resolve_pr_conflicts.sh
```

This script will:
1. Checkout each conflicting branch
2. Merge main with conflict resolution
3. Remove `boss-api/server.cjs` (accept deletion)
4. Use main's version of `scripts/smoke.sh`
5. Commit the resolution
6. Attempt to push (may require manual push due to permissions)

### Option 2: Manual Resolution

For each branch:

```bash
# Example for first branch
git checkout codex/add-user-authentication-feature
git merge origin/main

# Resolve conflicts
git rm boss-api/server.cjs
git checkout --theirs scripts/smoke.sh
git add scripts/smoke.sh

# Commit
git commit -m "Resolve merge conflicts with main

- Accept deletion of boss-api/server.cjs (architecture changed)
- Accept main's version of scripts/smoke.sh (tests current system)"

# Push
git push origin codex/add-user-authentication-feature
```

Repeat for all 4 branches.

### Option 3: Close Obsolete PRs

**Alternative approach:** Since these branches are based on an obsolete architecture, consider:

1. Close all 4 PRs as "won't fix" or "outdated"
2. Create a new authentication feature PR based on current architecture
3. Document why: "Architecture changed, original approach no longer applicable"

---

## Step-by-Step Manual Resolution

### Branch 1: codex/add-user-authentication-feature

```bash
git fetch origin
git checkout codex/add-user-authentication-feature
git merge origin/main

# You'll see:
# CONFLICT (modify/delete): boss-api/server.cjs
# CONFLICT (add/add): Merge conflict in scripts/smoke.sh

# Resolve:
git rm boss-api/server.cjs
git checkout --theirs scripts/smoke.sh
git add scripts/smoke.sh
git commit -m "Resolve merge conflicts with main"
git push origin codex/add-user-authentication-feature
```

### Branch 2: codex/add-user-authentication-feature-hhs830

```bash
git checkout codex/add-user-authentication-feature-hhs830
git merge origin/main
git rm boss-api/server.cjs
git checkout --theirs scripts/smoke.sh
git add scripts/smoke.sh
git commit -m "Resolve merge conflicts with main"
git push origin codex/add-user-authentication-feature-hhs830
```

### Branch 3: codex/add-user-authentication-feature-not1zo

```bash
git checkout codex/add-user-authentication-feature-not1zo
git merge origin/main
git rm boss-api/server.cjs
git checkout --theirs scripts/smoke.sh
git add scripts/smoke.sh
git commit -m "Resolve merge conflicts with main"
git push origin codex/add-user-authentication-feature-not1zo
```

### Branch 4: codex/add-user-authentication-feature-yiytty

```bash
git checkout codex/add-user-authentication-feature-yiytty
git merge origin/main
git rm boss-api/server.cjs
git checkout --theirs scripts/smoke.sh
git add scripts/smoke.sh
git commit -m "Resolve merge conflicts with main"
git push origin codex/add-user-authentication-feature-yiytty
```

---

## Post-Resolution Verification

After resolving conflicts, verify the branches:

```bash
# Run the verification script
./check_pr_conflicts.sh

# Should show:
# Total branches checked: 193
# Branches with conflicts: 0  ← Should be 0 now!
# Branches without conflicts: 193
```

---

## Recommendations

### Short-term

1. ✅ **Resolve conflicts** using automated script or manual steps above
2. ✅ **Verify resolution** by running conflict check again
3. ⚠️ **Consider consolidation** - all 4 branches are duplicates, keep only one

### Long-term

1. 🔄 **Rebase strategy** - Use rebase instead of merge for feature branches
2. 🧹 **Branch cleanup** - Delete duplicate/abandoned feature branches
3. 📋 **Architecture docs** - Document the new architecture to prevent similar issues
4. 🤖 **CI checks** - Add automated conflict detection to CI pipeline

---

## Additional Notes

### Why Multiple Branches?

The 4 branches appear to be retry attempts of the same feature:
- `-hhs830`, `-not1zo`, `-yiytty` are likely automated suffixes
- All branches have identical changes
- Suggests automated PR creation system

**Recommendation:** Consolidate to a single branch.

### Impact Assessment

After resolution, these branches will effectively be empty (no changes from main) because:
- The authentication changes targeted files that no longer exist
- The architecture changed completely
- No code from these branches will be integrated

**Consider:** Close PRs instead of merging if no value remains.

---

## Troubleshooting

### "Permission denied" on push

**Problem:** Cannot push to codex/* branches
```
error: RPC failed; HTTP 403
```

**Solutions:**
1. Check git remote authentication
2. Verify branch permissions
3. Contact repository admin
4. Use branch naming convention: `claude/*-sessionID`

### "Already up-to-date" after merge

**Problem:** Git says no conflicts but script detected them

**Solution:**
- The detection used `git merge-tree` (three-way comparison)
- Actual merge may differ - this is expected
- Trust actual `git merge` result

### Want to keep authentication feature

**Problem:** Need the authentication code

**Solution:**
1. Extract authentication logic from branch before resolving
2. Save to patch: `git show HEAD > auth-feature.patch`
3. Resolve conflicts as described
4. Create new branch based on current main
5. Re-implement authentication for new architecture

---

## Files Provided

- `check_pr_conflicts.sh` - Detection script (already run)
- `resolve_pr_conflicts.sh` - Automated resolution script (NEW)
- `pr_conflicts_report.txt` - Initial conflict report
- `PR_CONFLICTS_SUMMARY.md` - Executive summary
- `CONFLICT_RESOLUTION_GUIDE.md` - This file

---

## Questions?

If you need help:
1. Run automated script first: `./resolve_pr_conflicts.sh`
2. Check script output for specific errors
3. Review this guide for manual steps
4. Verify resolution with: `./check_pr_conflicts.sh`

---

**Last Updated:** November 4, 2025
**Status:** Ready for resolution
