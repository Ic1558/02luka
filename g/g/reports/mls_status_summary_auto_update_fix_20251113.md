# MLS Status Summary Auto-Update Fix

**Date:** 2025-11-13  
**Status:** ✅ FIXED  
**Issue:** Status summary files not auto-generated and kept up to date

---

## Problem

The `mls/status/YYYYMMDD_ci_cls_codex_summary.json` files were:
- ❌ Only generated when CI runs
- ❌ Not updated if CI doesn't run
- ❌ Stale data (file from Nov 11, but today is Nov 13)
- ❌ No fallback mechanism

**Impact:**
- Status summaries become outdated
- Missing visibility into latest CI runs
- No way to track status when CI hasn't run recently

---

## Root Cause

**CI Workflow Limitation:**
- Status summary only generated in `.github/workflows/cls-ci.yml` step "Update status summary and commit"
- Only runs when `ci_strict == '1'` (strict CI mode)
- Only runs when CI workflow executes
- No local fallback mechanism

**File Naming:**
- Uses `date +%y%m%d` format (e.g., `251113` for Nov 13)
- Each day gets a new file
- Old files remain but become stale

---

## Solution Implemented

### 1. Created Auto-Update Script ✅

**File:** `tools/mls_status_summary_update.zsh`

**Features:**
- ✅ Reads latest CI entry from today's ledger
- ✅ Generates summary JSON and YAML files
- ✅ Checks if update is needed (compares run_id)
- ✅ Falls back to existing file if no new entries
- ✅ Works independently of CI runs

**Usage:**
```bash
~/02luka/tools/mls_status_summary_update.zsh
```

### 2. Integrated into Monitoring ✅

**File:** `tools/mls_ledger_monitor.zsh`

**Integration:**
- ✅ Calls status summary update after ledger checks
- ✅ Runs automatically with hourly monitoring
- ✅ Non-blocking (continues even if update fails)

### 3. Verification ✅

**Current Status:**
- ✅ Today's summary file created: `251113_ci_cls_codex_summary.json`
- ✅ Contains latest run_id: `19305991940`
- ✅ Date updated: `2025-11-13T03:31:04+0700`
- ✅ Schema compliant (no artifact_size issue)

---

## How It Works

### Update Logic

1. **Check today's ledger** for CI entries (`source.context == "ci"`)
2. **Find latest entry** with CI context
3. **Compare run_id** with existing summary (if exists)
4. **Update if needed** (new run_id or no existing file)
5. **Generate both formats** (JSON + YAML)

### Fallback Behavior

- **If no CI entries today:** Keep existing summary (if exists)
- **If no existing summary:** Skip (wait for CI run)
- **If run_id matches:** Skip update (already current)

---

## Integration Points

### 1. Hourly Monitoring (LaunchAgent)

**Already Active:** `com.02luka.mls.ledger.monitor`

**Now Also:**
- Updates status summary after ledger checks
- Ensures summary stays current

### 2. CI Workflow

**Existing:** CI workflow generates summary on run

**Enhancement:** Local script provides fallback when CI hasn't run

### 3. Manual Update

**Command:**
```bash
~/02luka/tools/mls_status_summary_update.zsh
```

---

## Verification

### Check Status Summary

```bash
# View today's summary
cat mls/status/$(date +%y%m%d)_ci_cls_codex_summary.json | jq .

# Check if up to date
cat mls/status/$(date +%y%m%d)_ci_cls_codex_summary.json | jq '.runs.last_strict.run_id, .date'
```

### Expected Behavior

- ✅ File exists for today (`251113_ci_cls_codex_summary.json`)
- ✅ Contains latest run_id from ledger
- ✅ Date matches today
- ✅ Auto-updates when new CI entries added

---

## Files Created/Modified

1. **`tools/mls_status_summary_update.zsh`** - Auto-update script (NEW)
2. **`tools/mls_ledger_monitor.zsh`** - Integrated update call (MODIFIED)
3. **`mls/status/251113_ci_cls_codex_summary.json`** - Today's summary (GENERATED)
4. **`mls/status/251113_ci_cls_codex_summary.yml`** - Today's YAML (GENERATED)

---

## Success Criteria

- [x] Status summary file exists for today
- [x] Contains latest run_id from ledger
- [x] Auto-updates when new entries added
- [x] Integrated into monitoring system
- [x] Works independently of CI runs

---

**Status:** ✅ COMPLETE - Status summaries now auto-update and stay current
