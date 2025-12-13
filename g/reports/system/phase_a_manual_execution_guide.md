# Phase A: Manual Execution Guide
**Generated:** 2025-12-13  
**Status:** ⚠️ Shell Environment Issue - Manual Execution Required

---

## 🔴 Current Situation

**Problem:** Terminal commands failing due to shell environment setup (`cursor_snap_ENV_VARS`, `dump_zsh_state`)

**Solution:** Execute Python scripts directly or use clean terminal session

---

## ✅ What's Already Done

1. ✅ **Guard Script Patched** - `tools/guard_workspace_inside_repo.zsh` (line 39 fixed)
2. ✅ **Pre-commit Hook Patched** - `.git/hooks/pre-commit` (blocking mode restored)
3. ✅ **Migration Scripts Created** - Ready for execution

---

## 📋 Manual Execution Steps

### Option 1: Use Python Script (Recommended)

Open a **clean terminal** (not Cursor's integrated terminal) and run:

```bash
cd ~/02luka

# Step 1: Check current status
python3 tools/phase_a_verify.py

# Step 2: Migrate paths
python3 tools/phase_a_migrate_direct.py

# Step 3: Verify guard script
zsh tools/guard_workspace_inside_repo.zsh

# Step 4: Verify pre-commit hook
head -5 .git/hooks/pre-commit
# Should show: exec zsh tools/guard_workspace_inside_repo.zsh
```

### Option 2: Manual Commands (If Python fails)

```bash
cd ~/02luka

# 1. Migrate followup.json
mkdir -p ~/02luka_ws/g/apps/dashboard/data
cp g/apps/dashboard/data/followup.json ~/02luka_ws/g/apps/dashboard/data/followup.json
rm g/apps/dashboard/data/followup.json
ln -sfn ~/02luka_ws/g/apps/dashboard/data/followup.json g/apps/dashboard/data/followup.json

# 2. Create symlinks for directories (if they don't exist)
mkdir -p ~/02luka_ws/g/followup
ln -sfn ~/02luka_ws/g/followup g/followup

mkdir -p ~/02luka_ws/mls/ledger
ln -sfn ~/02luka_ws/mls/ledger mls/ledger

mkdir -p ~/02luka_ws/bridge/processed
ln -sfn ~/02luka_ws/bridge/processed bridge/processed

# 3. Verify
zsh tools/guard_workspace_inside_repo.zsh
```

---

## 🎯 Expected Results

After execution, you should see:

```
✅ g/followup -> /Users/icmini/02luka_ws/g/followup
✅ mls/ledger -> /Users/icmini/02luka_ws/mls/ledger
✅ bridge/processed -> /Users/icmini/02luka_ws/bridge/processed
✅ g/apps/dashboard/data/followup.json -> /Users/icmini/02luka_ws/g/apps/dashboard/data/followup.json

✅ All workspace guards passed
```

---

## 📝 Notes

- **Why Manual?** Shell environment in Cursor has parsing errors
- **Workaround:** Use clean terminal or Python scripts
- **Safety:** All scripts use safe operations (copy before delete)
- **Verification:** Guard script will confirm success

---

**Status:** Scripts ready, awaiting manual execution in clean terminal
