# save.sh Verification Fix Plan

**Date:** 2025-11-15  
**Issue:** save.sh missing from repo and lacks verification step  
**MLS Note:** `mls/ledger/2025-11-14.jsonl` - "save.sh still not do verify"  
**Status:** 📋 **PLAN READY FOR IMPLEMENTATION**

---

## Issue Analysis

### Current State
- **save.sh location:** Missing from repo (exists only in backups/archives)
- **Last known location:** `CLC/commands/save.sh` (from session reports)
- **Current location in archives:** `/Volumes/lukadata/_old_gd_mirror/02luka/02luka-repo/a/section/clc/commands/save.sh`
- **Verification:** Missing - script completes without verification step

### Relationship to MLS Auto-Update Issue

**These are SEPARATE issues:**

1. **MLS Auto-Update Issue:**
   - Problem: LaunchAgent can't execute `mls_cursor_watcher.zsh`
   - Root cause: LaunchAgent execution environment issue
   - Status: KeepAlive fixed, execution error persists
   - Impact: No automatic prompt capture

2. **save.sh Verification Issue:**
   - Problem: Script missing + no verification before completion
   - Root cause: Script not in repo, verification step never implemented
   - Status: Needs restoration + verification hook
   - Impact: Saves complete without verification

**Connection:**
- Both affect MLS system but are independent
- save.sh may write to MLS ledger (needs verification)
- Fixing save.sh won't fix cursor watcher execution issue

---

## Implementation Plan

### Phase 1: Restore save.sh Script

**Step 1.1: Copy from Archive**
```bash
# Source: /Volumes/lukadata/_old_gd_mirror/02luka/02luka-repo/a/section/clc/commands/save.sh
# Target: ~/02luka/tools/save.sh (recommended location)
```

**Step 1.2: Review Script**
- Understand current save logic (3 layers: session file, 02luka.md, CLAUDE_MEMORY_SYSTEM.md)
- Identify where verification should be inserted
- Check for existing flags or environment variables

**Step 1.3: Update Paths**
- Ensure script uses `LUKA_SOT` environment variable
- Update paths to match current repo structure
- Test script execution

### Phase 2: Add Verification Hook

**Step 2.1: Identify Verification Command**
- Check for existing verification scripts:
  - `tools/ci_check.zsh`
  - `tools/auto_verify_template.sh`
  - Other verification tools
- Determine appropriate verification command

**Step 2.2: Add Verification Step**
- Insert verification after save logic completes
- Capture exit code
- Fail save if verification fails (unless `--skip-verify` flag)

**Step 2.3: Add --skip-verify Flag**
- Add flag parsing
- Gate verification behind flag
- Emit loud warning when flag is used
- Default: always verify

**Step 2.4: Add Summary Output**
- Emit verification summary:
  - Tests run
  - Duration
  - Pass/fail status
- Format for dashboard scraping
- Log to MLS ledger

### Phase 3: Documentation & Testing

**Step 3.1: Update Documentation**
- Update `02luka.md` "Memory Save Protocol" section
- Document verification hook
- Document `--skip-verify` flag
- Update session summary template

**Step 3.2: Add MLS Entry**
- Record fix in MLS ledger
- Close earlier note (2025-11-14)
- Add as regression test case

**Step 3.3: End-to-End Testing**
- Test save with verification (should pass)
- Test save with `--skip-verify` (should warn)
- Test save with verification failure (should fail)
- Verify all three layers still written
- Verify summary output format

---

## Implementation Details

### Verification Command Options

**Option 1: Use Existing CI Check**
```bash
tools/ci_check.zsh --view-mls
```

**Option 2: Use Auto-Verify Template**
```bash
tools/auto_verify_template.sh system_health
```

**Option 3: Create Lightweight Verification**
```bash
tools/verify_save.sh
```

### Script Structure (Proposed)

```bash
#!/usr/bin/env zsh
# save.sh - Memory Save Protocol with Auto-Verify
set -euo pipefail

SKIP_VERIFY=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-verify)
      SKIP_VERIFY=true
      echo "⚠️  WARNING: Verification skipped (--skip-verify flag)" >&2
      shift
      ;;
    *)
      # Handle other args
      shift
      ;;
  esac
done

# ... existing save logic (3 layers) ...

# Phase 4: Verification (NEW)
if [[ "$SKIP_VERIFY" != "true" ]]; then
  echo "→ Running verification..."
  VERIFY_START=$(date +%s)
  
  if tools/ci_check.zsh --view-mls; then
    VERIFY_EXIT=0
    VERIFY_STATUS="PASS"
  else
    VERIFY_EXIT=$?
    VERIFY_STATUS="FAIL"
  fi
  
  VERIFY_DURATION=$(($(date +%s) - VERIFY_START))
  
  # Emit summary
  echo "Verification Summary:"
  echo "  Status: $VERIFY_STATUS"
  echo "  Duration: ${VERIFY_DURATION}s"
  echo "  Tests: ci_check.zsh --view-mls"
  
  if [[ $VERIFY_EXIT -ne 0 ]]; then
    echo "❌ Verification failed - save aborted" >&2
    exit $VERIFY_EXIT
  fi
fi

echo "✅ SAVE COMPLETE"
```

---

## Files to Modify/Create

### New Files
1. `tools/save.sh` - Restored script with verification hook
2. `tools/verify_save.sh` - Lightweight verification script (if needed)
3. `docs/save_verification.md` - Documentation for verification hook

### Modified Files
1. `02luka.md` - Update "Memory Save Protocol" section
2. `g/reports/sessions/*.md` - Update session summary template
3. `mls/ledger/YYYY-MM-DD.jsonl` - Add fix entry

---

## Success Criteria

1. ✅ save.sh restored to repo (in `tools/`)
2. ✅ Verification hook added and working
3. ✅ `--skip-verify` flag implemented with warning
4. ✅ Verification summary emitted
5. ✅ Documentation updated
6. ✅ MLS entry added (closing 2025-11-14 note)
7. ✅ End-to-end test passes

---

## Next Steps

1. **Restore save.sh from archive**
2. **Review and update script**
3. **Add verification hook**
4. **Test end-to-end**
5. **Update documentation**
6. **Add MLS entry**

---

**Plan Status:** 📋 **READY FOR IMPLEMENTATION**  
**Priority:** Medium (separate from MLS auto-update issue)  
**Estimated Time:** 1-2 hours
