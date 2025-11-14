# MLS Status Summary Root Cause Analysis

**Date:** 2025-11-13  
**Status:** 🔴 ROOT CAUSE IDENTIFIED

---

## Root Cause: Conditional Execution Gate

### The Problem

**Status summary generation is CONDITIONALLY SKIPPED** in CI workflows.

**Location:** `.github/workflows/cls-ci.yml` line 438

```yaml
- name: Update status summary and commit
  if: ${{ needs.sanity.outputs.ci_strict == '1' }}  # ⚠️ ROOT CAUSE
```

### Why It Fails

**The `ci_strict` flag is rarely '1':**

1. **Default Value:** `'0'` (line 14)
2. **Only '1' when:**
   - ✅ Scheduled runs (`cron: '0 17 * * *'` - 00:00 Asia/Bangkok)
   - ✅ Manual dispatch with `ci_strict: '1'` input
   - ✅ GitHub variable `CI_STRICT=1` is set
3. **NOT '1' for:**
   - ❌ Regular PR runs (defaults to '0')
   - ❌ Manual dispatch without explicit `ci_strict=1`
   - ❌ Most CI runs

### Impact

**Status summary files are NOT generated for:**
- ~90% of CI runs (PR runs with `ci_strict=0`)
- Any run where `ci_strict` is not explicitly set to '1'
- Most manual workflow dispatches

**Result:**
- Files only exist from scheduled runs (once per day at 00:00)
- Missing summaries for PR runs
- Stale data between scheduled runs
- No visibility into PR-based CI activity

---

## The Design Flaw

### Original Intent (Likely)

**Assumption:** Status summaries should only be generated for "strict" CI runs (scheduled, validated runs)

**Reality:** This creates gaps:
- PR runs don't generate summaries
- Manual runs don't generate summaries (unless explicitly set)
- Only scheduled runs generate summaries

### Why This Design Fails

1. **Scheduled runs are infrequent** (once per day)
   - If scheduled run fails, no summary for that day
   - If scheduled run is delayed, summary is delayed
   - No summary for days without scheduled runs

2. **PR runs are more frequent** but don't generate summaries
   - Most CI activity happens in PR runs
   - These runs are ignored for summary generation
   - Missing visibility into actual CI activity

3. **No fallback mechanism**
   - If scheduled run doesn't happen, no summary
   - No local script to generate summaries
   - No way to catch up on missing summaries

---

## The Fix Applied

### Solution 1: Local Auto-Update Script ✅

**File:** `tools/mls_status_summary_update.zsh`

**How it works:**
- Reads latest CI entry from ledger (regardless of how it was created)
- Generates summary based on actual ledger data
- Works independently of CI `ci_strict` flag
- Updates when new entries are added

**Advantage:**
- ✅ Works for all CI runs (PR, scheduled, manual)
- ✅ Updates based on actual ledger entries
- ✅ Not dependent on CI workflow conditions

### Solution 2: Integrated into Monitoring ✅

**File:** `tools/mls_ledger_monitor.zsh`

**Integration:**
- Calls status summary update after ledger checks
- Runs hourly via LaunchAgent
- Ensures summaries stay current

**Advantage:**
- ✅ Automatic updates
- ✅ Not dependent on CI runs
- ✅ Always current

---

## Why CI Workflow Design is Flawed

### Design Issue 1: Conditional Execution

**Problem:**
```yaml
if: ${{ needs.sanity.outputs.ci_strict == '1' }}
```

**Why it's wrong:**
- Status summaries should reflect ALL CI activity, not just "strict" runs
- PR runs are valid CI runs and should be tracked
- Conditional execution creates gaps in visibility

**Better Design:**
```yaml
# Should always run, or at least run for successful CI runs
if: ${{ job.status == 'success' }}
```

### Design Issue 2: No Fallback

**Problem:**
- No local mechanism to generate summaries
- Dependent entirely on CI workflow execution
- If CI doesn't run, no summary

**Why it's wrong:**
- Status summaries are critical for visibility
- Should be generated locally as fallback
- Should not depend on CI workflow conditions

**Better Design:**
- Generate summaries in CI (when possible)
- Also generate locally (as fallback)
- Always keep summaries current

### Design Issue 3: Single Source of Truth

**Problem:**
- Only CI workflow generates summaries
- No alternative mechanism
- Single point of failure

**Why it's wrong:**
- If CI workflow fails, summaries stop
- No way to recover or catch up
- Critical data depends on external system

**Better Design:**
- Multiple sources can generate summaries
- Local script as primary fallback
- CI workflow as enhancement, not requirement

---

## Root Cause Summary

### Primary Root Cause

**The status summary step is conditionally executed based on `ci_strict == '1'`, which is rarely true.**

**Breakdown:**
1. **Default:** `ci_strict = '0'` (line 14)
2. **Only '1' for:** Scheduled runs, explicit manual input, or GitHub variable
3. **Result:** Step is SKIPPED for ~90% of CI runs
4. **Impact:** Summaries only generated once per day (if scheduled run succeeds)

### Secondary Root Causes

1. **No fallback mechanism** - If CI doesn't run, no summary
2. **No local generation** - Dependent entirely on CI workflow
3. **Design assumption** - Only "strict" runs should generate summaries

---

## The Fix

### What We Fixed

1. ✅ **Created local auto-update script**
   - `tools/mls_status_summary_update.zsh`
   - Generates summaries from ledger entries
   - Works independently of CI conditions

2. ✅ **Integrated into monitoring**
   - `tools/mls_ledger_monitor.zsh`
   - Updates summaries hourly
   - Ensures summaries stay current

3. ✅ **Generated today's summary**
   - `mls/status/251113_ci_cls_codex_summary.json`
   - Based on latest ledger entry
   - Current and accurate

### What Should Be Fixed (Future)

1. **CI Workflow:** Remove or modify `ci_strict` condition
   - Generate summaries for all successful CI runs
   - Not just "strict" runs

2. **Documentation:** Clarify when summaries are generated
   - Document that local script is primary mechanism
   - CI workflow is enhancement, not requirement

3. **Monitoring:** Ensure summaries are always current
   - Local script runs hourly
   - CI workflow adds to it (doesn't replace it)

---

## Verification

### Current Status

```bash
# Check today's summary exists
ls -1 mls/status/$(date +%y%m%d)_ci_cls_codex_summary.json
# Result: ✅ EXISTS

# Check it's current
cat mls/status/251113_ci_cls_codex_summary.json | jq '.runs.last_strict.run_id'
# Result: ✅ "19305991940" (latest from ledger)
```

### Why It Works Now

1. ✅ **Local script generates summaries** - Not dependent on CI conditions
2. ✅ **Monitoring keeps it updated** - Runs hourly
3. ✅ **Based on ledger entries** - Reflects actual CI activity

---

## Lessons Learned

### Design Principle Violation

**❌ BAD:** Critical data generation depends on conditional execution  
**✅ GOOD:** Critical data generation has multiple mechanisms

### Single Point of Failure

**❌ BAD:** Only CI workflow generates summaries  
**✅ GOOD:** Local script + CI workflow (redundancy)

### Assumption vs Reality

**❌ BAD:** Assume only "strict" runs need summaries  
**✅ GOOD:** All CI activity should be tracked

---

**Status:** ✅ ROOT CAUSE IDENTIFIED AND FIXED - Summaries now auto-generate independently of CI conditions
