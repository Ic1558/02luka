# Code Review: Emergency Repository Recovery

**Date:** 2025-11-14  
**Reviewer:** CLS  
**Type:** Emergency Recovery Plan Review

---

## Review Summary

### ✅ APPROVED - Safe Recovery Plan

**Verdict:** ✅ **SAFE TO EXECUTE** with minor path adjustments

**Reasoning:**
- Plan is well-structured with clear phases
- Backup steps protect against data loss
- Reset strategy is safe (backup first, reset second)
- WO Pipeline v2 restoration is straightforward

---

## Risk Analysis

### High Risk Areas

**R1: Path Mismatch**
- **Issue:** Scripts use `BASE="$HOME/02luka"` but repo is at `~/02luka/g`
- **Impact:** Scripts may not find correct directory
- **Mitigation:** Verify paths before execution, adjust if needed

**R2: LaunchAgent Path**
- **Issue:** LaunchAgent name is `com.02luka.auto.commit` (not `auto_commit_work`)
- **Impact:** May miss disabling actual LaunchAgent
- **Mitigation:** Check actual LaunchAgent names before unloading

**R3: Sync Scripts Location**
- **Issue:** Scripts are in `~/02luka/tools/` not `~/02luka/g/tools/`
- **Impact:** Need to disable from correct location
- **Mitigation:** Use absolute paths, verify before disabling

### Medium Risk Areas

**R4: Backup Verification**
- **Issue:** Need to verify backups before proceeding
- **Impact:** May proceed with incomplete backup
- **Mitigation:** Add verification steps after each backup

**R5: Git State**
- **Issue:** Detached HEAD may cause unexpected behavior
- **Impact:** Reset may not work as expected
- **Mitigation:** Use `git switch main` before reset

---

## Style Check

### ✅ Good Practices

1. **Backup First:** Full repo backup before any destructive operations
2. **Separate Backups:** WO Pipeline v2 backed up separately
3. **Verification Steps:** Each phase has success criteria
4. **Rollback Plan:** Clear recovery path if things fail

### ⚠️ Areas for Improvement

1. **Path Consistency:** Need to handle `~/02luka` vs `~/02luka/g` difference
2. **LaunchAgent Names:** Need to verify actual LaunchAgent names
3. **Error Handling:** Add more error checks between steps

---

## History-Aware Review

### Previous Issues

**From Codex Chat Archive:**
- Repository shows 1,900+ deleted files
- HEAD detached from `22aa833`
- WO Pipeline v2 files still exist (Codex created them)

**From CLS Analysis:**
- Auto-sync scripts may push broken state
- Risk of deleting entire GitHub repo
- Need immediate stop of sync operations

### Context

**Current State:**
- `~/02luka/g` - Main repo (detached HEAD, mass deletions shown)
- `~/02luka/tools/` - Scripts location (different from repo)
- WO Pipeline v2 exists in `~/02luka/g/tools/wo_pipeline/`

**Expected Outcome:**
- Repository reset to clean state
- WO Pipeline v2 preserved on separate branch
- Sync operations stopped

---

## Obvious Bug Scan

### ⚠️ Potential Issues

**Bug 1: Path Mismatch**
- Scripts reference `~/02luka` but repo is `~/02luka/g`
- **Fix:** Use `~/02luka/g` for repo operations, `~/02luka/tools/` for scripts

**Bug 2: LaunchAgent Name**
- Plan says `com.02luka.auto_commit_work.plist`
- Actual is `com.02luka.auto.commit.plist`
- **Fix:** Check actual LaunchAgent names before unloading

**Bug 3: Script Location**
- Scripts are in `~/02luka/tools/` not `~/02luka/g/tools/`
- **Fix:** Use correct paths when disabling scripts

---

## Diff Hotspots

### Critical Changes

1. **Disable Sync Scripts:**
   - Location: `~/02luka/tools/ensure_remote_sync.zsh`
   - Location: `~/02luka/tools/auto_commit_work.zsh`
   - Action: Rename to `.DISABLED`

2. **Unload LaunchAgents:**
   - Actual: `com.02luka.auto.commit.plist`
   - Location: `~/Library/LaunchAgents/`
   - Action: Unload

3. **Repository Reset:**
   - Location: `~/02luka/g`
   - Action: `git reset --hard origin/main`

4. **WO Pipeline v2 Restore:**
   - Source: `/tmp/wo_pipeline_backup/`
   - Target: `~/02luka/g/tools/wo_pipeline/`
   - Action: Copy and commit

---

## Final Verdict

### ✅ APPROVED - Execute with Path Adjustments

**Recommendations:**
1. ✅ Verify actual LaunchAgent names before unloading
2. ✅ Use correct paths (`~/02luka/g` for repo, `~/02luka/tools/` for scripts)
3. ✅ Add verification after each backup
4. ✅ Test git operations on test branch first (if time permits)

**Confidence Level:** High (95%)
- Plan is sound
- Backups protect against loss
- Path adjustments are minor
- Recovery steps are clear

**Ready to Execute:** ✅ Yes, with minor path adjustments

---

**Reviewer:** CLS  
**Date:** 2025-11-14  
**Status:** ✅ APPROVED

