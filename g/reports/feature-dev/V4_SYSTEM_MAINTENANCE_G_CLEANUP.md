# V4 System Maintenance: /g Folder Structure Cleanup

**Created:** 2025-11-21
**Category:** System Maintenance
**Priority:** P3 (Low urgency, high value)
**Status:** 🟡 SPEC PHASE - Parked for V4

---

## 📋 Task Overview

Clean up nested and broken `/g` folder structures discovered during Gemini integration Phase 2 work.

**Problem:** System has accumulated orphaned directory structures:
- `/02luka/g/g/` (1.9 MB nested orphan)
- `/02luka/~/02luka/g/` (164 KB broken tilde path)

**Goal:** Restore clean single-source-of-truth structure without breaking any active systems.

---

## 🎯 Spec & Plan

### Phase 1: Pre-Cleanup Validation (1 hour)

**Checklist:**
- [ ] Re-run reference audit to confirm zero active dependencies
- [ ] Verify all LaunchAgents still use correct paths
- [ ] Check git status of main `/02luka/g` repo
- [ ] Create manual backup to external drive (optional):
  ```bash
  tar czf ~/Desktop/02luka_g_backup_$(date +%Y%m%d).tar.gz ~/02luka/g
  ```
- [ ] Review analysis report: `~/02luka/g/reports/system/G_STRUCTURE_CLEANUP_ANALYSIS.md`

### Phase 2: Cleanup Execution (15 minutes)

**Script Location:** `~/02luka/tools/fix_g_structure_cleanup.zsh.DISABLED`

**Execution:**
```bash
# Enable the script (remove .DISABLED suffix)
mv ~/02luka/tools/fix_g_structure_cleanup.zsh.DISABLED \
   ~/02luka/tools/fix_g_structure_cleanup.zsh

# Run cleanup (requires "YES" confirmation)
bash ~/02luka/tools/fix_g_structure_cleanup.zsh

# Review output for success messages
```

**What It Does:**
1. Creates timestamped archive: `~/02luka/_archive/g_cleanup_YYYYMMDD_HHMMSS/`
2. Moves nested `/g/g/` → archive
3. Moves broken tilde path → archive
4. Removes empty parent directories
5. Validates main `/g` structure integrity
6. Logs metadata for audit trail

### Phase 3: Post-Cleanup Validation (30 minutes)

**Validation Checklist:**
- [ ] Main git repo intact: `ls -la ~/02luka/g/.git`
- [ ] Tools work: `bash ~/02luka/tools/agent_status.zsh`
- [ ] LaunchAgents running: `launchctl list | grep 02luka`
- [ ] Work order system: `bash ~/02luka/tools/wo_router.zsh --help`
- [ ] Dashboard accessible: `curl -s http://127.0.0.1:8766 | head -10`
- [ ] Archive created: `ls -lah ~/02luka/_archive/g_cleanup_*/`

### Phase 4: Monitoring Period (1 week)

**Watch For:**
- Any errors in agent logs mentioning missing paths
- LaunchAgent failures related to `/g` paths
- Broken symlinks (unlikely based on audit)

**Daily Check:**
```bash
# Quick health check
~/02luka/tools/agent_status.zsh
tail -20 ~/02luka/logs/system.log
```

### Phase 5: Archive Cleanup (Optional)

After 1 week of successful operation:
```bash
# Verify archive location
ls -lah ~/02luka/_archive/g_cleanup_*/

# Delete archive (saves ~2 MB)
rm -rf ~/02luka/_archive/g_cleanup_*
```

---

## 🛡️ Safety Analysis

### Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Breaking active scripts | 🟢 Low | High | ✅ Zero references found in audit |
| Data loss | 🟢 Low | High | ✅ Archive-first strategy |
| Git corruption | 🟢 Low | Critical | ✅ Main repo validated before cleanup |
| Rollback needed | 🟢 Low | Medium | ✅ Archive preserved for 1 week |

**Overall Risk:** 🟢 **LOW - Safe to proceed in V4**

### Rollback Plan

If issues arise post-cleanup:
```bash
# 1. Identify archive timestamp
ARCHIVE=$(ls -dt ~/02luka/_archive/g_cleanup_* | head -1)

# 2. Restore nested /g/g
mv "$ARCHIVE/nested_g_g" ~/02luka/g/g

# 3. Restore tilde path
mkdir -p ~/02luka/~
mv "$ARCHIVE/tilde_path_g" ~/02luka/~/02luka/g

# 4. Verify restoration
find ~/02luka/g/g -type f | wc -l  # Should show 63 files
```

---

## 📊 Expected Outcome

### Before Cleanup
```
~/02luka/
├── g/                 (257 MB) ✅ Main repo
│   └── g/             (1.9 MB) ❌ CHAOS
├── _memory/g/         (48 KB) ✅ Backup
└── ~/02luka/g/        (164 KB) ❌ CHAOS

Structure confusion: 4 /g locations
```

### After Cleanup
```
~/02luka/
├── g/                 (257 MB) ✅ Single source of truth
├── _memory/g/         (48 KB) ✅ Backup preserved
└── _archive/
    └── g_cleanup_20251121_HHMMSS/
        ├── nested_g_g/      (1.9 MB archived)
        ├── tilde_path_g/    (164 KB archived)
        └── metadata/

Structure clarity: 1 active /g, 1 backup, 1 archive
```

**Benefits:**
- ✅ Eliminates confusion about which `/g` is correct
- ✅ Prevents future scripts from accidentally using nested paths
- ✅ Cleans up ~2 MB orphaned data
- ✅ Simplifies mental model for developers
- ✅ Reduces cognitive load when debugging path issues

---

## 🔧 Prevention Measures

### Path Validation Function (Add to Common Library)

```bash
# File: ~/02luka/lib/path_validation.zsh

validate_g_path() {
  local target="$1"

  # Check for nested /g/g
  if [[ "$target" =~ /g/g ]]; then
    echo "❌ ERROR: Nested /g/g path detected: $target" >&2
    return 1
  fi

  # Check for literal tilde
  if [[ "$target" =~ ~/.*$ ]]; then
    echo "❌ ERROR: Literal tilde in path: $target" >&2
    echo "   Use \$HOME instead of ~" >&2
    return 1
  fi

  # Check for multiple /g/ occurrences
  local g_count=$(echo "$target" | grep -o "/g/" | wc -l)
  if [[ $g_count -gt 1 ]]; then
    echo "⚠️  WARNING: Multiple /g/ in path: $target" >&2
    return 1
  fi

  return 0
}

# Export for use in all scripts
export -f validate_g_path 2>/dev/null || true
```

### Update Future Migration Scripts

Add to any script that moves `/g` data:
```bash
# Source validation library
source ~/02luka/lib/path_validation.zsh

# Validate before moving
TARGET="$HOME/02luka/g/reports"
if ! validate_g_path "$TARGET"; then
  echo "❌ Invalid path, aborting"
  exit 1
fi

# Safe to proceed
mv "$SOURCE" "$TARGET"
```

---

## 📚 Related Documentation

**Analysis Report:** `/Users/icmini/02luka/g/reports/system/G_STRUCTURE_CLEANUP_ANALYSIS.md`
**Cleanup Script:** `/Users/icmini/02luka/tools/fix_g_structure_cleanup.zsh.DISABLED`
**DRY RUN Script:** `/tmp/fix_g_structure_DRYRUN.zsh`

**Related Issues:**
- Recursive directory anti-pattern (Oct 11, 2024 centralization script)
- Literal tilde path expansion bug

---

## 🎓 MLS Lesson Candidate

**Pattern ID:** `PATH-001-RECURSIVE-DIR-ANTIPATTERN`
**Category:** System Architecture / Path Management
**Type:** Anti-Pattern / Failure Mode

**Problem:** Script created `legacy_parent/legacy_parent/legacy_parent/...` (3+ levels deep)

**Root Cause:**
```bash
# BAD - creates infinite nesting
while [[ -d "$OLD_DIR" ]]; do
  mv "$OLD_DIR" "$OLD_DIR/legacy_parent"
done
```

**Solution:**
```bash
# GOOD - move to separate archive
ARCHIVE="$SOT/_archive/migration_$(date +%Y%m%d)"
mkdir -p "$ARCHIVE"
mv "$OLD_DIR" "$ARCHIVE/$(basename "$OLD_DIR")"
```

**Impact:** High (causes confusion, wastes space, breaks debugging)

**To Capture:**
```bash
bash ~/02luka/tools/mls_capture.zsh \
  --type "failure" \
  --category "path_management" \
  --lesson "Never nest directories recursively during migrations - use separate archive directory" \
  --evidence "~/02luka/g/reports/system/G_STRUCTURE_CLEANUP_ANALYSIS.md"
```

---

## ✅ V4 Execution Criteria

**Ready to Execute When:**
- [ ] V4 system maintenance sprint begins
- [ ] No critical work orders in flight
- [ ] Dashboard and autopilot stable for 7+ days
- [ ] Manual backup created (optional but recommended)
- [ ] CLC available for monitoring during cleanup

**Estimated Time:** 2 hours (including validation periods)
**Assignee:** CLC or designated system maintenance role
**Priority:** P3 (nice-to-have, non-urgent)

---

## 📞 Support

**Questions?** Reference analysis report or ask CLC.

**Execution Approval:** Requires user confirmation before running cleanup script.

**Status Updates:** This document will be updated as phases complete.

---

**Next Action:** Park this task until V4 system maintenance sprint. No immediate action required.
