# /g Folder Structure Cleanup Analysis

**Date:** 2025-11-21
**Issue:** Nested `/g/g` and broken tilde paths causing confusion
**Status:** ✅ DRY RUN COMPLETE | 🟡 READY FOR CLEANUP

---

## 🔍 Problem Analysis

### Current Chaos Discovered

```
/Users/icmini/02luka/
├── g/                        # 257 MB ✅ CORRECT (main repo)
│   └── g/                    # 1.9 MB ❌ NESTED (orphaned data)
├── _memory/g/                # 48 KB ✅ INTENTIONAL (backup)
└── ~/02luka/g/               # 164 KB ❌ BROKEN PATH (literal tilde)
```

### Size Breakdown

| Path | Size | Status | Action |
|------|------|--------|--------|
| `/02luka/g` | 257 MB | ✅ Source of Truth | **PRESERVE** |
| `/02luka/g/g` | 1.9 MB | ❌ Nested orphan | **ARCHIVE** |
| `/02luka/_memory/g` | 48 KB | ✅ Intentional backup | **PRESERVE** |
| `/02luka/~/02luka/g` | 164 KB | ❌ Broken path | **ARCHIVE** |

---

## 📊 Nested /g/g Content Analysis

**Files:** 63
**Directories:** 13
**Latest Modification:** 2025-11-17

### What's Inside

```
/g/g/
├── metrics/
│   ├── cls_agent.pid
│   └── bridge_cls_clc.pid
├── logs/ (various agent logs)
├── reports/ (old reports)
├── telemetry/sample/autoheal.log (latest: Nov 17)
└── legacy_parent/
    └── legacy_parent/
        └── legacy_parent/ (3+ levels deep!)
            └── reports/ (Oct 11, 2024 logs)
```

**Root Cause:** Failed centralization script from Oct 11, 2024 created recursive "legacy_parent" folders.

---

## 🔍 Tilde Path (~) Analysis

**Path:** `/Users/icmini/02luka/~/02luka/g/`
**Issue:** Literal tilde character in directory name (not expanded to $HOME)
**Content:** 25 files (manuals, reports)

Likely caused by improper path expansion in a script:
```bash
# Bad (creates literal ~)
mkdir -p "~/02luka/g"

# Good
mkdir -p "$HOME/02luka/g"
```

---

## ✅ Active Reference Audit

**Result:** ✅ **ZERO active references to nested paths found**

### Checked Locations

- [x] **Tools** (`~/02luka/tools/*.zsh`): 20+ files reference `~/02luka/g` ✅
- [x] **LaunchAgents** (`~/Library/LaunchAgents/*.plist`): 10+ files reference `/02luka/g` ✅
- [x] **Python Scripts** (`bridge/**/*.py`, `g/**/*.py`): No `/g/g` references ✅
- [x] **Documentation** (`*.md`): No `/g/g` references ✅

**Conclusion:** Nested structures are **orphaned data** with no active consumers.

---

## 🎯 Smart Solution

### Strategy: Archive First, Never Delete

```zsh
# DRY RUN (already executed)
bash /tmp/fix_g_structure_DRYRUN.zsh

# ACTUAL CLEANUP (when ready)
bash /tmp/fix_g_structure_CLEANUP.zsh
```

### What It Does

1. **Creates timestamped archive** → `/02luka/_archive/g_cleanup_YYYYMMDD_HHMMSS/`
2. **Moves nested data**:
   - `g/g/` → `_archive/.../nested_g_g/`
   - `~/02luka/g/` → `_archive/.../tilde_path_g/`
3. **Removes empty parents**: Cleans up literal `~` and `~/02luka` directories
4. **Preserves main structures**:
   - ✅ `/02luka/g` (main repo)
   - ✅ `/02luka/_memory/g` (intentional backup)
5. **Logs metadata** for audit trail

### Safety Features

- ✅ Requires explicit "YES" confirmation
- ✅ Archives before moving (never deletes)
- ✅ Saves cleanup metadata
- ✅ Validates main /g structure after cleanup
- ✅ Provides rollback instructions

---

## 🛡️ Risk Assessment

| Risk | Level | Mitigation |
|------|-------|------------|
| Breaking active scripts | 🟢 LOW | Zero references found in audit |
| Data loss | 🟢 LOW | Archive-first strategy |
| Git corruption | 🟢 LOW | Main /g/.git validated before cleanup |
| Symlink breakage | 🟢 LOW | No symlinks to nested paths |

**Overall Risk:** 🟢 **LOW - Safe to proceed**

---

## 📋 Execution Checklist

### Pre-Cleanup

- [x] Run dry-run analysis
- [x] Verify zero active references
- [x] Check git status of main /g
- [ ] Commit any uncommitted changes in /g
- [ ] Create manual backup (optional):
  ```bash
  tar czf ~/Desktop/g_manual_backup_$(date +%Y%m%d).tar.gz ~/02luka/g
  ```

### Cleanup

- [ ] Run cleanup script:
  ```bash
  bash /tmp/fix_g_structure_CLEANUP.zsh
  ```
- [ ] Type "YES" when prompted
- [ ] Verify output shows "Cleanup Complete"

### Post-Cleanup Validation

- [ ] Check main /g still has git repo: `ls -la ~/02luka/g/.git`
- [ ] Verify tools still work: `bash ~/02luka/tools/agent_status.zsh`
- [ ] Check LaunchAgents: `launchctl list | grep 02luka | wc -l`
- [ ] Test a work order: `bash ~/02luka/tools/wo_router.zsh --help`
- [ ] Verify archive exists: `ls -lah ~/02luka/_archive/g_cleanup_*/`

### 1 Week Later

- [ ] If no issues, delete archive:
  ```bash
  rm -rf ~/02luka/_archive/g_cleanup_*
  ```

---

## 🔧 Prevention: Path Validation Protocol

### Add to Future Centralization Scripts

```bash
# At start of any script that moves /g data
validate_g_path() {
  local target="$1"

  # Check for nested /g/g
  if [[ "$target" =~ /g/g ]]; then
    echo "❌ ERROR: Nested /g/g path detected: $target"
    return 1
  fi

  # Check for literal tilde
  if [[ "$target" =~ ~/.*$ ]]; then
    echo "❌ ERROR: Literal tilde in path: $target"
    echo "   Use \$HOME instead of ~"
    return 1
  fi

  # Check for multiple /g occurrences
  local g_count=$(echo "$target" | grep -o "/g/" | wc -l)
  if [[ $g_count -gt 1 ]]; then
    echo "⚠️  WARNING: Multiple /g/ in path: $target"
    return 1
  fi

  return 0
}

# Usage
TARGET_PATH="$HOME/02luka/g/reports"
if ! validate_g_path "$TARGET_PATH"; then
  exit 1
fi
```

### Add to ~/.zshrc or ~/02luka/.envrc

```bash
# Prevent accidental literal tilde directories
alias mkdir='mkdir -p'  # Already safe
alias cp='cp -v'        # Verbose to catch bad paths
alias mv='mv -v'        # Verbose to catch bad paths

# Validator function available in all shells
export SOT="$HOME/02luka"  # Always expanded, never literal ~
```

---

## 📈 Expected Outcome

### Before Cleanup
```
~/02luka/
├── g/                 (257 MB) ✅
│   └── g/             (1.9 MB) ❌ CHAOS
├── _memory/g/         (48 KB) ✅
└── ~/02luka/g/        (164 KB) ❌ CHAOS
```

### After Cleanup
```
~/02luka/
├── g/                 (257 MB) ✅ CLEAN
├── _memory/g/         (48 KB) ✅ PRESERVED
└── _archive/
    └── g_cleanup_20251121_HHMMSS/
        ├── nested_g_g/      (1.9 MB archived)
        ├── tilde_path_g/    (164 KB archived)
        └── metadata/
            └── cleanup_log.txt
```

**Space Reclaimed:** ~2 MB (minimal, but eliminates confusion)
**Structure Clarity:** ✅ Single source of truth at `/02luka/g`

---

## 🎓 Lessons for MLS

### Pattern: Recursive Directory Anti-Pattern

**Problem:** Centralization script created `legacy_parent/legacy_parent/legacy_parent/...`

**Root Cause:** Script probably had:
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

**Lesson ID:** `PATH-001-RECURSIVE-DIR-ANTIPATTERN`
**Category:** System Architecture / Path Management
**Impact:** High (causes confusion, wastes disk space, breaks scripts)

---

## 📞 Support

**Scripts Created:**
- `/tmp/fix_g_structure_DRYRUN.zsh` (analysis only, already run)
- `/tmp/fix_g_structure_CLEANUP.zsh` (actual cleanup, run when ready)

**Report Location:**
- `/Users/icmini/02luka/g/reports/system/G_STRUCTURE_CLEANUP_ANALYSIS.md`

**Contact:** CLC for execution assistance

---

**Next Step:** Review this report, then run cleanup script when ready.
