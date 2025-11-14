# Emergency Repository Recovery - Execution Guide

**Created:** 2025-11-14  
**Status:** Ready for Execution  
**Critical:** Execute immediately to prevent GitHub repo deletion

---

## ✅ What Was Created

### 1. Recovery Script
**File:** `/Users/icmini/02luka/tools/emergency_repo_recovery.zsh`

**What it does:**
- Phase 1: Stops all auto-sync (disables scripts, unloads LaunchAgents)
- Phase 2: Creates full repo backup (`~/02luka/g_backup_before_recovery`)
- Phase 3: Backs up WO Pipeline v2 (`/tmp/wo_pipeline_backup/`)
- Phase 4: Resets repository to clean state (matches `origin/main`)
- Phase 5: Restores WO Pipeline v2 on new branch (`feature/wo-pipeline-v2`)

### 2. Planning Documents
- `g/reports/feature_emergency_repo_recovery_SPEC.md` - Technical specification
- `g/reports/feature_emergency_repo_recovery_PLAN.md` - Detailed plan
- `g/reports/code_review_emergency_recovery_20251114.md` - Code review

---

## 🚨 CRITICAL: Execute Now

### Option 1: Run Recovery Script (Recommended)

```bash
cd ~/02luka
./tools/emergency_repo_recovery.zsh
```

**This will:**
1. ✅ Stop all auto-sync
2. ✅ Create full backup
3. ✅ Backup WO Pipeline v2
4. ✅ Reset repo to clean
5. ✅ Restore WO Pipeline v2 on new branch

**Time:** ~5-10 minutes

---

### Option 2: Manual Execution (If Script Fails)

**Phase 1: Stop Sync (2 min)**
```bash
cd ~/02luka
mv tools/ensure_remote_sync.zsh tools/ensure_remote_sync.zsh.DISABLED
mv tools/auto_commit_work.zsh tools/auto_commit_work.zsh.DISABLED
launchctl unload ~/Library/LaunchAgents/com.02luka.auto.commit.plist 2>/dev/null
```

**Phase 2: Full Backup (3 min)**
```bash
cp -R ~/02luka/g ~/02luka/g_backup_before_recovery
```

**Phase 3: WO Pipeline Backup (2 min)**
```bash
mkdir -p /tmp/wo_pipeline_backup/{tools,launchd,docs,followup}
cp -R ~/02luka/g/tools/wo_pipeline /tmp/wo_pipeline_backup/tools/
cp ~/02luka/g/launchd/com.02luka.*.plist /tmp/wo_pipeline_backup/launchd/
cp ~/02luka/g/docs/WO_PIPELINE_V2.md /tmp/wo_pipeline_backup/docs/
cp -R ~/02luka/g/followup/state /tmp/wo_pipeline_backup/followup/
```

**Phase 4: Reset (3 min)**
```bash
cd ~/02luka/g
git reset --hard
git fetch origin
git switch main
git reset --hard origin/main
git status  # Should show "working tree clean"
```

**Phase 5: Restore (5 min)**
```bash
cd ~/02luka/g
git switch -c feature/wo-pipeline-v2
mkdir -p tools/wo_pipeline launchd docs followup
cp -R /tmp/wo_pipeline_backup/tools/wo_pipeline/* tools/wo_pipeline/
cp /tmp/wo_pipeline_backup/launchd/*.plist launchd/
cp /tmp/wo_pipeline_backup/docs/WO_PIPELINE_V2.md docs/
cp -R /tmp/wo_pipeline_backup/followup/state followup/
chmod +x tools/wo_pipeline/*.zsh
git add tools/wo_pipeline/ launchd/ docs/ followup/state/
git commit -m "feat(wo_pipeline): restore WO Pipeline v2 from backup"
```

---

## ✅ Verification After Execution

### Check 1: Sync Stopped
```bash
ls ~/02luka/tools/*.DISABLED
# Should show: ensure_remote_sync.zsh.DISABLED, auto_commit_work.zsh.DISABLED

launchctl list | grep "02luka.*commit"
# Should return nothing
```

### Check 2: Backups Created
```bash
ls -ld ~/02luka/g_backup_before_recovery
# Should exist

ls -lhR /tmp/wo_pipeline_backup/
# Should show all WO Pipeline v2 files
```

### Check 3: Repository Clean
```bash
cd ~/02luka/g
git status
# Should show: "working tree clean"
git branch
# Should show: * feature/wo-pipeline-v2 (or main)
```

### Check 4: WO Pipeline v2 Restored
```bash
cd ~/02luka/g
ls -lh tools/wo_pipeline/*.zsh
# Should show 7 files
ls -lh launchd/com.02luka.*.plist
# Should show 5 files
ls -lh docs/WO_PIPELINE_V2.md
# Should exist
```

---

## 📊 Expected Results

### After Phase 1:
- ✅ Sync scripts disabled
- ✅ LaunchAgents unloaded
- ✅ No sync processes running

### After Phase 2:
- ✅ Full backup at `~/02luka/g_backup_before_recovery`

### After Phase 3:
- ✅ WO Pipeline v2 backup at `/tmp/wo_pipeline_backup/`

### After Phase 4:
- ✅ Repository on `main` branch
- ✅ `git status` shows "working tree clean"
- ✅ HEAD not detached

### After Phase 5:
- ✅ New branch `feature/wo-pipeline-v2` created
- ✅ WO Pipeline v2 files restored
- ✅ Files committed on branch

---

## 🎯 Next Steps (After Recovery)

### Immediate
1. ✅ Verify recovery successful
2. ✅ Review WO Pipeline v2 on new branch
3. ✅ Test WO Pipeline v2 scripts

### Future
1. ⏳ Investigate root cause of detached HEAD
2. ⏳ Fix auto-sync scripts with safeguards
3. ⏳ Restore deleted root files from git history
4. ⏳ Design safe sync system with guardrails

---

## ⚠️ Important Notes

### DO NOT:
- ❌ Push current broken state to GitHub
- ❌ Run any git push commands
- ❌ Re-enable sync scripts until fixed
- ❌ Delete backups until recovery verified

### DO:
- ✅ Run recovery script immediately
- ✅ Verify backups before proceeding
- ✅ Test WO Pipeline v2 after restore
- ✅ Document what happened

---

**Status:** ⚠️ **CRITICAL - Execute Recovery Script Now**

**Script Location:** `~/02luka/tools/emergency_repo_recovery.zsh`

**Command:** `cd ~/02luka && ./tools/emergency_repo_recovery.zsh`
