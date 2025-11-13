# Feature SPEC: Emergency Repository Recovery

**Created:** 2025-11-14  
**Priority:** P0 (CRITICAL - Emergency)  
**Owner:** CLS  
**Status:** Immediate Action Required

---

## Problem Statement

### Critical Issue

**Repository State:**
- HEAD detached from `22aa833`
- Git status shows **1,900+ deleted files**
- Auto-sync scripts may push broken state to GitHub
- Risk: Entire repository deletion on GitHub if pushed

**Current Reality:**
- WO Pipeline v2 files **STILL EXIST** (Codex created them)
  - `tools/wo_pipeline/` - 7 scripts ✅
  - `launchd/` - 5 plist files ✅
  - `docs/WO_PIPELINE_V2.md` ✅
  - `followup/state/` ✅
- Root-level files deleted (02luka.md, .gitignore, etc.)
- Detached HEAD causing Git to show false deletions

**Risk:**
- If auto-sync pushes → **GitHub repo deleted**
- Cannot recover from remote if broken state pushed

---

## Objectives

### Primary Goals

1. **STOP ALL SYNC** - Prevent any git push operations
2. **BACKUP SAFELY** - Preserve WO Pipeline v2 work
3. **RESET CLEAN** - Restore repository to clean state
4. **RESTORE WORK** - Put WO Pipeline v2 on separate branch

### Success Criteria

✅ **Phase 1: Stop Sync**
- All auto-sync scripts disabled
- All sync LaunchAgents unloaded
- No git push processes running

✅ **Phase 2: Backup**
- Full repo backup created
- WO Pipeline v2 backed up separately
- Backup verified

✅ **Phase 3: Recovery**
- Repository reset to clean state
- Main branch matches remote
- WO Pipeline v2 on separate branch
- All files committed properly

---

## Scope

### In Scope

**Emergency Recovery (5 phases):**
1. Stop all sync operations
2. Full repository backup
3. WO Pipeline v2 backup
4. Repository reset to clean
5. Restore WO Pipeline v2 on new branch

### Out of Scope

- Restoring deleted root files (future work)
- Fixing sync scripts (future work)
- Investigating root cause (future work)

---

## Technical Design

### Phase 1: Stop Sync

**Actions:**
- Rename sync scripts to `.DISABLED`
- Unload sync LaunchAgents
- Verify no sync processes running

**Scripts to Disable:**
- `tools/ensure_remote_sync.zsh`
- `tools/auto_commit_work.zsh`

**LaunchAgents to Unload:**
- `com.02luka.ensure_remote_sync.plist`
- `com.02luka.auto_commit_work.plist`

### Phase 2: Backup

**Full Repo Backup:**
- Copy `~/02luka/g` to `~/02luka/g_backup_before_recovery`
- Safety net for recovery

**WO Pipeline v2 Backup:**
- Copy to `/tmp/wo_pipeline_backup/`
- Include: scripts, LaunchAgents, docs, state

### Phase 3: Reset

**Steps:**
1. `git reset --hard` (clean working tree)
2. `git fetch origin` (get latest)
3. `git switch main` (switch branch)
4. `git reset --hard origin/main` (match remote)

**Expected Result:**
- `git status` shows "working tree clean"
- Main branch matches GitHub

### Phase 4: Restore

**Steps:**
1. Create `feature/wo-pipeline-v2` branch
2. Copy files from backup
3. Make scripts executable
4. Commit on new branch

**Files to Restore:**
- `tools/wo_pipeline/*.zsh` (7 files)
- `launchd/com.02luka.*.plist` (5 files)
- `docs/WO_PIPELINE_V2.md`
- `followup/state/`

---

## Dependencies

### Required
- Access to `~/02luka/g` directory
- Git repository intact
- `/tmp/` directory writable
- LaunchAgent access

### Optional
- Remote repository accessible (for reset)

---

## Risk Assessment

### High Risk

**R1: Backup fails**
- **Mitigation:** Verify backup before proceeding
- **Mitigation:** Create full repo backup first

**R2: Reset loses work**
- **Mitigation:** Backup FIRST, reset SECOND
- **Mitigation:** Verify WO Pipeline v2 backup complete

**R3: Auto-sync still running**
- **Mitigation:** Check processes after unload
- **Mitigation:** Verify no git processes

### Medium Risk

**R4: Files don't restore**
- **Mitigation:** Verify backup before restore
- **Mitigation:** Check file existence after copy

---

## Success Metrics

### Phase 1
- ✅ All sync scripts disabled
- ✅ All LaunchAgents unloaded
- ✅ No sync processes running

### Phase 2
- ✅ Full repo backup exists
- ✅ WO Pipeline v2 backup verified
- ✅ Backup files match source

### Phase 3
- ✅ Repository reset to clean
- ✅ Main branch matches remote
- ✅ `git status` shows clean

### Phase 4
- ✅ New branch created
- ✅ WO Pipeline v2 files restored
- ✅ Files committed on branch

---

## Rollback Plan

**If Recovery Fails:**
1. Use full repo backup: `~/02luka/g_backup_before_recovery`
2. Use WO Pipeline v2 backup: `/tmp/wo_pipeline_backup/`
3. Manual file recovery if needed

---

**Next:** Create detailed PLAN with step-by-step commands.
