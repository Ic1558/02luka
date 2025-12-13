# Phase C Final Checklist
**Date:** 2025-12-13  
**Status:** Ready for Execution

---

## ✅ Pre-Execution Checklist

### 0. Restore Corrupted Files (if needed)

```bash
cd ~/02luka
git status --porcelain

# If files are corrupted, restore:
git checkout HEAD -- \
  g/docs/ADR_001_workspace_split.md \
  g/reports/system/phase_c_patch_verification.md \
  tools/bootstrap_workspace.zsh

# Verify restore
git status --porcelain
```

### 1. Verify PATH-Safe Functions

**File:** `tools/phase_c_execute.zsh`

**Check:**
- [x] PATH exported (line 5)
- [x] All safe functions defined (lines 8-37)
- [x] All commands use safe functions

**Status:** ✅ Verified (see `phase_c_path_safe_verification.md`)

---

## 🚀 Execution Steps

### Step 1: Run Phase C Tests

```bash
cd ~/02luka
zsh tools/phase_c_execute.zsh
```

**Expected Results:**
- ✅ Test 1: Safe Clean Dry-Run - PASS
- ✅ Test 2: Pre-commit Failure - PASS
- ✅ Test 3: Guard Verification - PASS
- ✅ Test 4: Bootstrap Verification - PASS

### Step 2: Verify All Tests Pass

If all 4 tests pass:
```
✅✅✅ All tests passed! System is hardened. ✅✅✅
```

### Step 3: Commit (if all tests pass)

```bash
cd ~/02luka
git status --porcelain
git add tools/phase_c_execute.zsh
git commit -m "fix(phase-c): make phase_c_execute PATH-safe (absolute core utils)"
git push
```

---

## 🔍 Troubleshooting

### If Test 3 fails with "command not found: rm"

**Issue:** Still using unsafe `rm` command  
**Fix:** Check that all `rm` calls use `rm_safe`

### If Test 4 fails with bootstrap error

**Issue:** Bootstrap script may have issues  
**Fix:** Check `tools/bootstrap_workspace.zsh` is correct

### If any test fails

**Check logs:**
```bash
cat /tmp/phase_c_test1.log
cat /tmp/phase_c_test2_commit.log
cat /tmp/phase_c_test4.log
```

---

## 📋 Files Status

- ✅ `tools/phase_c_execute.zsh` - PATH-safe verified
- ✅ `tools/bootstrap_workspace.zsh` - Should be restored if corrupted
- ✅ `tools/guard_workspace_inside_repo.zsh` - Working
- ✅ `.git/hooks/pre-commit` - Working

---

**Status:** Ready for execution
