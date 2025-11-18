# PR #368 Rebase Strategy

**Date:** 2025-11-18  
**PR:** #368  
**Status:** 📋 **REBASE PLAN**

---

## Current Situation

**Branch:** `feat/pr298-complete-migration`  
**Base:** `origin/main`  
**Status:** CONFLICTING/DIRTY

**Issues:**
1. Untracked files that would be overwritten
2. `run/` directory permission issues (temp files)
3. Need to rebase on latest main

---

## Rebase Strategy

### Step 1: Clean Working Directory

1. **Remove untracked files that conflict:**
   ```bash
   # These are likely from other work, move or remove
   rm g/docs/CONTEXT_ENGINEERING_PROTOCOL_v3.md
   rm g/docs/CONTEXT_ENGINEERING_PROTOCOL_v3.schema.json
   # ... etc
   ```

2. **Handle run/ directory:**
   - These are temp files, not in git
   - Can be ignored for rebase

### Step 2: Rebase on Main

```bash
git fetch origin main
git rebase origin/main
```

### Step 3: Resolve Conflicts

**Expected conflicts in:**
- `g/apps/dashboard/dashboard.js`
- `g/apps/dashboard/index.html`
- Possibly other dashboard files

**Resolution strategy:**
- Keep our pipeline metrics additions
- Merge main's changes (likely timeline features)
- Ensure both features work together

### Step 4: Test

- Verify dashboard loads
- Check pipeline metrics display
- Verify timeline features still work

### Step 5: Push

```bash
git push --force-with-lease origin feat/pr298-complete-migration
```

---

## Alternative: Merge Strategy

If rebase is too complex:

1. Merge main into branch
2. Resolve conflicts
3. Test
4. Push

---

**Status:** Ready to execute  
**Next:** Clean working directory and rebase

