# .env.local Workspace Migration
**Date:** 2025-12-14  
**Issue:** `.env.local` kept getting deleted by git clean / bootstrap / symlink operations  
**Root Cause:** `.gitignore` only prevents tracking, not deletion by `git clean`, `rm -rf`, or symlink replacement  
**Solution:** Move to workspace and symlink (aligns with workspace split ADR)

---

## Problem Analysis

### Why `.env.local` Was Being Deleted

**Misconception:**
> "It's gitignored, so Git shouldn't touch it"

**Reality:**
`.gitignore` only affects **tracking**, not **filesystem operations**.

**Operations that DELETE gitignored files:**
- ❌ `git clean -fd` - Deletes untracked files (including ignored)
- ❌ `git reset --hard` - Resets to HEAD (can remove untracked)
- ❌ `rm -rf <dir>` - Removes directory and all contents
- ❌ Symlink replacement - Replaces directory with symlink
- ❌ Bootstrap scripts - Recreate directories

**Operations that PROTECT gitignored files:**
- ✅ `git add` - Won't add ignored files
- ✅ `git commit` - Won't commit ignored files
- ✅ `git pull` - Won't overwrite ignored files

---

## Root Causes (Ranked)

### 1. `git clean -fd` (Most Common)
- Deletes all untracked files, even if gitignored
- Your system has `safe_git_clean.zsh` to prevent this
- But if `.env.local` is in repo → still vulnerable

### 2. Directory Recreation
Scripts that do:
```bash
rm -rf some_dir
mkdir some_dir
```
Examples:
- `bootstrap_workspace.zsh`
- Phase C test cleanup
- Guard repair scripts
- Symlink repair logic

### 3. Symlink Replacement
If directory becomes symlink:
```bash
rm -rf g/apps/dashboard
ln -s ~/02luka_ws/g/apps/dashboard g/apps/dashboard
```
→ All real files in that directory are lost

### 4. Bootstrap/Safety Scripts
Your aggressive safety system:
- Guards
- Bootstrap
- Safe clean
- Symlink enforcement
- Phase C cleanup

**These are working correctly** - they destroy unsafe runtime state in repo.

---

## Solution: Workspace-Based Storage

### Architecture

**Before (Vulnerable):**
```
~/02luka/.env.local  (real file in repo)
```

**After (Protected):**
```
~/02luka_ws/env/.env.local  (real file in workspace)
~/02luka/.env.local          (symlink → workspace)
```

### Benefits

- ✅ Survives `git clean -fd`
- ✅ Survives `git reset --hard`
- ✅ Survives directory recreation
- ✅ Survives symlink replacement
- ✅ Aligns with workspace split ADR
- ✅ Matches production-grade practice

---

## Implementation

### Migration Steps (Completed)

1. ✅ Created workspace env directory: `~/02luka_ws/env/`
2. ✅ Moved `.env.local` to workspace: `~/02luka_ws/env/.env.local`
3. ✅ Created symlink: `~/02luka/.env.local` → `~/02luka_ws/env/.env.local`
4. ✅ Verified symlink works

### Verification

```bash
# Check symlink
ls -la ~/02luka/.env.local

# Check target exists
test -f ~/02luka_ws/env/.env.local && echo "✅ Target exists"

# Verify not tracked
git status --porcelain | grep "\.env" || echo "✅ Not tracked"
```

---

## Bootstrap Integration

**Current:** `bootstrap_workspace.zsh` should ensure `.env.local` symlink exists.

**Recommended addition:**
```bash
# Ensure .env.local symlink exists
if [[ ! -L "$REPO/.env.local" ]] && [[ -f "$LOCAL/env/.env.local" ]]; then
  ln -sfn "$LOCAL/env/.env.local" "$REPO/.env.local"
fi
```

---

## Guard Integration

**Current:** `guard_workspace_inside_repo.zsh` checks workspace paths.

**Recommended addition:**
```bash
# Warn if .env.local is real file (should be symlink)
if [[ -f "$REPO/.env.local" ]] && [[ ! -L "$REPO/.env.local" ]]; then
  echo "⚠️  WARN: .env.local is a real file (should be symlink to workspace)"
  echo "   Run: ln -sfn ~/02luka_ws/env/.env.local ~/02luka/.env.local"
fi
```

---

## Key Principle

**Rule:**
> If losing a file would hurt, it must not live in the repo tree unless it's tracked.

**`.env.local` characteristics:**
- ❌ Not tracked
- ❌ Not immutable
- ❌ Not reproducible
- ➡️ **Therefore: workspace only**

---

## Status

- ✅ Migration complete
- ✅ Symlink created
- ✅ File protected in workspace
- ⏳ Bootstrap integration (optional)
- ⏳ Guard integration (optional)

---

**Last Updated:** 2025-12-14  
**Architecture:** Aligns with ADR_001_workspace_split
