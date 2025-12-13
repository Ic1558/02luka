# Phase C Final Fix Commands
**Date:** 2025-12-13  
**Status:** Ready for Clean Terminal Execution

---

## 🔴 Issues to Fix

1. **Test 3 Cleanup Failed:** `g/data` and `g/telemetry` are real directories (should be symlinks)
2. **Bad Substitution Fixed:** `${(@k)backups}` syntax corrected
3. **Push Rejected:** Need to pull remote changes first

---

## 📋 Commands to Run (Clean Terminal)

### Step 1: Restore Broken Symlinks

```bash
cd ~/02luka

# Restore g/data
rm -rf g/data
mkdir -p ~/02luka_ws/g/data
ln -sfn ~/02luka_ws/g/data g/data

# Restore g/telemetry
rm -rf g/telemetry
mkdir -p ~/02luka_ws/g/telemetry
ln -sfn ~/02luka_ws/g/telemetry g/telemetry

# Verify
zsh tools/guard_workspace_inside_repo.zsh
```

**Expected:** All workspace guards passed ✅

---

### Step 2: Pull Remote Changes

```bash
cd ~/02luka
git pull --rebase
```

**If conflicts:** Resolve and continue rebase

---

### Step 3: Commit & Push

```bash
cd ~/02luka

# Check status
git status --porcelain

# Add fixed file
git add tools/phase_c_execute.zsh

# Commit
git commit -m "fix(phase-c): make phase_c_execute PATH-safe (absolute core utils)"

# Push
git push
```

---

## ✅ Verification

After Step 1, verify:

```bash
# Check symlinks
ls -la g/data g/telemetry

# Should show:
# g/data -> /Users/icmini/02luka_ws/g/data
# g/telemetry -> /Users/icmini/02luka_ws/g/telemetry

# Run guard
zsh tools/guard_workspace_inside_repo.zsh
# Should pass ✅
```

---

## 🎯 Quick One-Liner (Alternative)

If you prefer using the fix script:

```bash
cd ~/02luka
zsh tools/fix_test3_cleanup.zsh && git pull --rebase && git add tools/phase_c_execute.zsh && git commit -m "fix(phase-c): make phase_c_execute PATH-safe (absolute core utils)" && git push
```

---

**Status:** Ready for execution in clean terminal
