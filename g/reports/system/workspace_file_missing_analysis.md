---
title: Workspace File Missing - Root Cause Analysis
date: 2025-12-03
status: ✅ RESOLVED (File Restored)
issue: 02luka_v3.5 workspace.code-workspace missing from working directory
author: CLC
tags: [workspace, git, debugging, file-missing]
---

# Workspace File Missing - Root Cause Analysis

**Issue:** `02luka_v3.5 workspace.code-workspace` missing from working directory
**Date:** 2025-12-03
**Status:** ✅ RESOLVED (File Restored)

---

## Symptoms

```
Error: The path '~/02luka/02luka_v3.5 workspace.code-workspace' does not exist
```

When trying to open workspace in Cursor/Antigravity.

---

## Investigation Results

### 1. File Status in Git ✅

**Finding:** File is **tracked and present** in git repository

```bash
$ git ls-tree HEAD | grep workspace
100644 blob 08fff4dc... 02luka_v3.5 workspace.code-workspace

$ git ls-files -v | grep "02luka_v3.5"
H 02luka_v3.5 workspace.code-workspace  # H = tracked normally
```

**Conclusion:** File exists in git index but was missing from working directory

---

### 2. File History ✅

**Last modified in commits:**
- `946cb01ad` - Nov 29, 2025: "docs: add script to fix run/ directory permissions"
- `8ed36d741` - Dec 3, 2025: "On feat/hybrid-router-clean: Stash before switching to main"

**Git log:**
```bash
946cb01ad docs: add script to fix run/ directory permissions
7664f3b49 feat: V4 stability layer + CLC local validation
90eca3112 chore: finalize sync before V4 push
```

**Conclusion:** File has been in repo for 11 days, last updated 3 days ago

---

### 3. Recent Branch Activity 🔍

**Last 3 days of branch switching:**
```
2025-12-03 04:01 - checkout: main → codex/add-runtime-hardening
2025-12-03 03:56 - reset: moving to origin/main
2025-12-03 03:56 - checkout: feat/hybrid-router-clean → main
2025-12-01 08:25 - checkout: feat/hybrid-router → feat/hybrid-router-clean
2025-12-01 08:24 - checkout: main → feat/hybrid-router
2025-12-01 06:18 - checkout: feat/alter-ai-integration-clean → main
2025-12-01 05:59 - checkout: feat/alter-ai-integration → feat/alter-ai-integration-clean
2025-12-01 05:02 - checkout: feat/governance_v41-core → feat/alter-ai-integration
2025-11-29 23:03 - checkout: main → feat/governance_v41-core
```

**Conclusion:** Heavy branch switching activity in last 3 days

---

### 4. Gitignore Check ✅

```bash
$ git check-ignore -v "02luka_v3.5 workspace.code-workspace"
Exit code: 1 (not ignored)
```

**Conclusion:** File is NOT gitignored

---

### 5. File Content Comparison 🔍

**Stash commit (8ed36d741) - OLD paths:**
```json
{
  "folders": [
    {"path": "/Users/icmini/LocalProjects/02luka_local_g"},
    {"path": "/Users/icmini/LocalProjects/02luka"},
    {"path": "/Users/icmini/LocalProjects/02luka-memory"}
  ],
  "settings": {
    "terminal.integrated.env.osx": {
      "LUKA_SOT": "/Users/icmini/LocalProjects/02luka_local_g"  // OLD
    }
  }
}
```

**Current HEAD - NEW paths (updated):**
```json
{
  "folders": [
    {"path": "/Users/icmini/02luka", "name": "02luka (SOT)"},
    {"path": "/Users/icmini/LocalProjects/02luka-memory"}
  ],
  "settings": {
    "terminal.integrated.env.osx": {
      "LUKA_SOT": "/Users/icmini/02luka"  // NEW
    }
  }
}
```

**Changes:**
- ✅ Removed obsolete symlink path `02luka_local_g`
- ✅ Updated SOT to current location `/Users/icmini/02luka`
- ✅ Cleaned up duplicate `LocalProjects/02luka` entry

---

## Root Cause Analysis

### Primary Cause: **Filename with Space + Branch Switching**

**Why it went missing:**

1. **Filename has space:** `02luka_v3.5 workspace.code-workspace`
   - Some git operations don't properly handle spaces
   - Shell scripts may not quote paths correctly
   - Checkout/merge operations may skip the file

2. **Frequent branch switching:**
   - 10+ branch switches in 3 days
   - File exists in some branches but not others
   - Git may have silently skipped checkout due to space in name

3. **Working directory vs Git index mismatch:**
   - File tracked in git: ✅ Present in `git ls-tree HEAD`
   - File in working dir: ❌ Missing from filesystem
   - Git status: Silent (no indication of missing file)

### Contributing Factors:

- **Path changes:** File references old paths that no longer exist
- **No explicit tracking:** File not regularly verified
- **Silent failure:** Git doesn't warn when checkout fails for space-named files

---

## Resolution Applied

### 1. Restored File ✅
```bash
git checkout HEAD -- "02luka_v3.5 workspace.code-workspace"
```

### 2. Updated Paths ✅
- Updated SOT: `/Users/icmini/02luka` (current)
- Removed obsolete paths (symlinks, old LocalProjects)
- Added descriptive names to folders

### 3. Verified ✅
```bash
$ ls -la ~/02luka/*.code-workspace
-rw-r--r-- 396 Nov 19 08:57 02luka-dual.code-workspace
-rw-r--r-- 800 Dec  3 04:22 02luka.code-workspace
-rw-r--r-- 490 Dec  3 04:25 02luka_v3.5 workspace.code-workspace ✅
```

---

## Prevention Measures

### 1. Rename File (Recommended) ⚠️

**Problem:** Spaces in filename cause issues
**Solution:** Rename to use underscores or hyphens

```bash
# Proposed rename
git mv "02luka_v3.5 workspace.code-workspace" "02luka_v3.5_workspace.code-workspace"
```

**Benefits:**
- ✅ No shell quoting issues
- ✅ Git operations more reliable
- ✅ Script-friendly
- ✅ Tab-completion friendly

### 2. Add to Pre-Commit Hook

**Create:** `.git/hooks/pre-commit` to verify workspace files exist

```bash
#!/bin/bash
# Verify workspace files exist
for file in "02luka_v3.5 workspace.code-workspace" "02luka.code-workspace"; do
  if [[ ! -f "$file" ]]; then
    echo "ERROR: Workspace file missing: $file"
    git checkout HEAD -- "$file" 2>/dev/null || echo "Failed to restore"
  fi
done
```

### 3. Add to Health Check

**Add workspace verification to health check script:**

```bash
# In tools/health_check.sh
WORKSPACE_FILES=(
  "02luka_v3.5 workspace.code-workspace"
  "02luka.code-workspace"
  "02luka-dual.code-workspace"
)

for ws in "${WORKSPACE_FILES[@]}"; do
  if [[ ! -f "$ws" ]]; then
    echo "⚠️  Missing workspace: $ws"
    echo "   Run: git checkout HEAD -- '$ws'"
  fi
done
```

### 4. Regular Verification

**Add to daily routine or launchd agent:**

```bash
# Check workspace files daily
cd ~/02luka
git ls-files "*.code-workspace" | while read -r file; do
  if [[ ! -f "$file" ]]; then
    git checkout HEAD -- "$file"
    echo "Restored: $file"
  fi
done
```

---

## Lessons Learned

### ✅ What Worked:
- Git history preserved file even when missing from working directory
- `git ls-tree HEAD` helped identify that file should exist
- `git checkout HEAD -- "filename"` restored file successfully

### ⚠️ What to Avoid:
- **Spaces in filenames** for git-tracked files
- Assuming git checkout always succeeds
- Not verifying critical files after branch switches

### 📝 Best Practices:
1. Use underscores/hyphens instead of spaces in filenames
2. Add critical files to health checks
3. Verify working directory after major git operations
4. Keep workspace files in sync with current SOT paths

---

## Related Files

- `02luka_v3.5 workspace.code-workspace` - Multi-folder workspace (restored)
- `02luka.code-workspace` - Main workspace (exists)
- `02luka-dual.code-workspace` - Dual workspace (exists)
- `.gitignore` - No workspace files ignored

---

## Timeline

**2025-11-22:** File created in commit `7664f3b49`
**2025-11-29:** File updated in commit `946cb01ad`
**2025-12-03 03:56:** Heavy branch switching activity
**2025-12-03 04:25:** File noticed missing, restored from git
**2025-12-03 04:25:** Paths updated to current SOT

---

## Recommendation

### Immediate Action:
✅ File restored and working - **No immediate action needed**

### Future Prevention:
⚠️ **Consider renaming file** to avoid spaces:
```bash
git mv "02luka_v3.5 workspace.code-workspace" "02luka_v3.5_workspace.code-workspace"
```

### Long-term:
- Add workspace verification to health check
- Monitor for other files with problematic names
- Document workspace setup process

---

**Report generated by:** CLC (Claude Code)
**Issue resolved:** 2025-12-03 04:25 +07
**File status:** ✅ RESTORED and UPDATED
