# Feature PLAN: Emergency Repository Recovery

**Created:** 2025-11-14  
**Priority:** P0 (CRITICAL)  
**Timeline:** 15-20 minutes (emergency response)  
**Status:** Ready for Immediate Execution

---

## Executive Summary

**Problem:** Repository in dangerous state (detached HEAD, 1,900+ deleted files shown). Auto-sync may push broken state to GitHub, deleting entire repo.

**Solution:** 5-phase emergency recovery:
1. Stop all sync (2 min)
2. Full repo backup (3 min)
3. WO Pipeline v2 backup (2 min)
4. Reset to clean (3 min)
5. Restore on new branch (5 min)

**Critical:** Must complete before any auto-sync runs.

---

## Implementation Tasks

### Phase 0: Emergency Stop (CRITICAL - Do First)

**Goal:** Prevent any git push operations

**Manual Actions Required:**
- ❌ **DO NOT** click push in Cursor
- ❌ **DO NOT** run `git push` in Terminal
- ❌ **DO NOT** let any script with `ensure_remote_sync`, `auto_commit`, `git push` run

**Status:** ⚠️ **MANUAL - User must ensure**

---

### Phase 1: Stop Auto-Sync (2 minutes)

**Task 1.1: Disable Sync Scripts**

```bash
cd ~/02luka

# Disable sync scripts (rename to .DISABLED)
mv tools/ensure_remote_sync.zsh tools/ensure_remote_sync.zsh.DISABLED 2>/dev/null
mv tools/auto_commit_work.zsh tools/auto_commit_work.zsh.DISABLED 2>/dev/null

# Verify disabled
ls -lh tools/*.DISABLED
```

**Success Criteria:**
- Scripts renamed to `.DISABLED`
- No executable sync scripts remain

---

**Task 1.2: Unload LaunchAgents**

```bash
# Unload sync LaunchAgents
launchctl unload ~/Library/LaunchAgents/com.02luka.ensure_remote_sync.plist 2>/dev/null
launchctl unload ~/Library/LaunchAgents/com.02luka.auto_commit_work.plist 2>/dev/null

# Verify unloaded
launchctl list | grep -i sync\|commit\|git
# Should return nothing
```

**Success Criteria:**
- No sync LaunchAgents in `launchctl list`
- All plists unloaded

---

**Task 1.3: Verify No Sync Processes**

```bash
# Check for running git sync processes
ps aux | grep "git push\|git pull\|ensure_remote_sync\|auto_commit_work" | grep -v grep

# Should return nothing
```

**Success Criteria:**
- No git sync processes running
- No auto-commit processes running

---

### Phase 2: Full Repository Backup (3 minutes)

**Task 2.1: Create Full Repo Backup**

```bash
cd ~

# Create full backup (safety net)
cp -R ~/02luka/g ~/02luka/g_backup_before_recovery

# Verify backup
ls -ld ~/02luka/g_backup_before_recovery
du -sh ~/02luka/g_backup_before_recovery
```

**Success Criteria:**
- Backup directory exists
- Backup size matches source (approximately)

**Note:** This is safety net - if reset fails, can recover from here.

---

### Phase 3: WO Pipeline v2 Backup (2 minutes)

**Task 3.1: Backup WO Pipeline v2 Files**

```bash
cd ~/02luka/g

# Create backup directory
mkdir -p /tmp/wo_pipeline_backup/{tools,launchd,docs,followup}

# Backup WO Pipeline scripts
cp -R tools/wo_pipeline /tmp/wo_pipeline_backup/tools/ 2>/dev/null

# Backup LaunchAgents
cp -R launchd/com.02luka.*.plist /tmp/wo_pipeline_backup/launchd/ 2>/dev/null

# Backup docs
cp docs/WO_PIPELINE_V2.md /tmp/wo_pipeline_backup/docs/ 2>/dev/null

# Backup state directory
cp -R followup/state /tmp/wo_pipeline_backup/followup/ 2>/dev/null

# Verify backup
ls -lhR /tmp/wo_pipeline_backup/
```

**Success Criteria:**
- Backup directory created
- All WO Pipeline v2 files copied
- Files verified in backup

**Expected Files:**
- `/tmp/wo_pipeline_backup/tools/wo_pipeline/*.zsh` (7 files)
- `/tmp/wo_pipeline_backup/launchd/*.plist` (5 files)
- `/tmp/wo_pipeline_backup/docs/WO_PIPELINE_V2.md`
- `/tmp/wo_pipeline_backup/followup/state/`

---

### Phase 4: Reset Repository to Clean (3 minutes)

**Task 4.1: Reset Working Tree**

```bash
cd ~/02luka/g

# Step 1: Reset working tree (discard all changes)
git reset --hard

# Step 2: Fetch latest from remote
git fetch origin

# Step 3: Switch to main branch
git switch main

# Step 4: Reset main to match remote exactly
git reset --hard origin/main

# Verify clean state
git status
```

**Success Criteria:**
- `git status` shows "working tree clean"
- On branch `main`
- HEAD not detached

**Expected Output:**
```
On branch main
Your branch is up to date with 'origin/main'.
nothing to commit, working tree clean
```

---

### Phase 5: Restore WO Pipeline v2 on New Branch (5 minutes)

**Task 5.1: Create New Branch**

```bash
cd ~/02luka/g

# Create and switch to new branch
git switch -c feature/wo-pipeline-v2

# Verify
git branch
# Should show: * feature/wo-pipeline-v2
```

**Success Criteria:**
- New branch created
- Currently on new branch

---

**Task 5.2: Restore Files from Backup**

```bash
cd ~/02luka/g

# Ensure directories exist
mkdir -p tools/wo_pipeline launchd docs followup

# Restore WO Pipeline scripts
cp -R /tmp/wo_pipeline_backup/tools/wo_pipeline/* tools/wo_pipeline/ 2>/dev/null

# Restore LaunchAgents
cp /tmp/wo_pipeline_backup/launchd/*.plist launchd/ 2>/dev/null

# Restore docs
cp /tmp/wo_pipeline_backup/docs/WO_PIPELINE_V2.md docs/ 2>/dev/null

# Restore state directory
cp -R /tmp/wo_pipeline_backup/followup/state followup/ 2>/dev/null

# Make scripts executable
chmod +x tools/wo_pipeline/*.zsh 2>/dev/null

# Verify restored
git status
```

**Success Criteria:**
- All files restored
- Scripts executable
- `git status` shows new/modified files

---

**Task 5.3: Commit WO Pipeline v2**

```bash
cd ~/02luka/g

# Stage WO Pipeline v2 files
git add tools/wo_pipeline/
git add launchd/com.02luka.*.plist
git add docs/WO_PIPELINE_V2.md
git add followup/state/

# Commit
git commit -m "feat(wo_pipeline): restore WO Pipeline v2 from backup

Recovered WO Pipeline v2 work created by Codex.
All 7 scripts, 5 LaunchAgents, docs, and state directory.

Files restored:
- tools/wo_pipeline/*.zsh (7 scripts)
- launchd/com.02luka.*.plist (5 LaunchAgents)
- docs/WO_PIPELINE_V2.md
- followup/state/

Recovery date: $(date +%Y-%m-%d)
Emergency recovery from detached HEAD state.
"

# Verify commit
git log --oneline -1
```

**Success Criteria:**
- Commit created on `feature/wo-pipeline-v2`
- All WO Pipeline v2 files committed
- Commit message documents recovery

---

## Test Strategy

### Unit Tests

**Test 1: Sync Stopped**
```bash
# Verify no sync scripts
ls tools/*.DISABLED
# Should show disabled scripts

# Verify no LaunchAgents
launchctl list | grep -i sync\|commit
# Should return nothing

# Verify no processes
ps aux | grep "git push\|ensure_remote_sync" | grep -v grep
# Should return nothing
```

**Test 2: Backup Verified**
```bash
# Verify full backup
ls -ld ~/02luka/g_backup_before_recovery
# Should exist

# Verify WO Pipeline backup
ls -lhR /tmp/wo_pipeline_backup/
# Should show all files
```

**Test 3: Repository Clean**
```bash
cd ~/02luka/g
git status
# Should show: "working tree clean"
git branch
# Should show: * feature/wo-pipeline-v2 (or main)
```

**Test 4: WO Pipeline v2 Restored**
```bash
cd ~/02luka/g
ls -lh tools/wo_pipeline/*.zsh
# Should show 7 files
ls -lh launchd/com.02luka.*.plist
# Should show 5 files
ls -lh docs/WO_PIPELINE_V2.md
# Should exist
ls -ld followup/state
# Should exist
```

---

## Timeline

**Total:** 15-20 minutes

| Phase | Time | Status |
|-------|------|--------|
| Phase 0: Emergency Stop | Manual | ⚠️ User action |
| Phase 1: Stop Sync | 2 min | ⏳ Pending |
| Phase 2: Full Backup | 3 min | ⏳ Pending |
| Phase 3: WO Pipeline Backup | 2 min | ⏳ Pending |
| Phase 4: Reset | 3 min | ⏳ Pending |
| Phase 5: Restore | 5 min | ⏳ Pending |

---

## Success Metrics

### Phase 1
- ✅ All sync scripts disabled
- ✅ All LaunchAgents unloaded
- ✅ No sync processes running

### Phase 2
- ✅ Full repo backup exists
- ✅ Backup verified

### Phase 3
- ✅ WO Pipeline v2 backed up
- ✅ All files verified in backup

### Phase 4
- ✅ Repository reset to clean
- ✅ Main branch matches remote
- ✅ HEAD not detached

### Phase 5
- ✅ New branch created
- ✅ WO Pipeline v2 files restored
- ✅ Files committed on branch

---

## Rollback Plan

**If Recovery Fails:**

1. **Use Full Backup:**
   ```bash
   # Restore entire repo from backup
   rm -rf ~/02luka/g
   cp -R ~/02luka/g_backup_before_recovery ~/02luka/g
   ```

2. **Use WO Pipeline Backup:**
   ```bash
   # Restore WO Pipeline v2 only
   cp -R /tmp/wo_pipeline_backup/* ~/02luka/g/
   ```

3. **Manual Recovery:**
   - Check git reflog for lost commits
   - Restore from remote if safe
   - Manual file recovery if needed

---

## Next Steps (After Recovery)

### Immediate
1. ✅ Verify recovery successful
2. ✅ Document what happened
3. ⏳ Review WO Pipeline v2 on new branch

### Future
- Investigate root cause of detached HEAD
- Fix auto-sync scripts with safeguards
- Restore deleted root files from git history
- Design safe sync system with guardrails

---

**Status:** ⚠️ **CRITICAL - Execute Immediately**

**DO NOT** proceed with any git operations until Phase 1 is complete.

**DO NOT** push current state to GitHub (will delete entire repo).
