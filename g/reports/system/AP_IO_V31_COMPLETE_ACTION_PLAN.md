# AP/IO v3.1 Complete Action Plan

**Date:** 2025-11-17  
**Status:** ⚠️ **FILES NEED RESTORATION FIRST**

---

## Current Situation

**Problem:** AP/IO v3.1 files were deleted and need to be restored before improvements can be implemented.

**Solution:** Use the restoration script, then implement improvements.

---

## Step 1: Restore Files

**Script:** `g/reports/system/AP_IO_V31_RESTORE_AND_IMPROVE_SCRIPT.zsh`

**Manual Command:**
```bash
cd /Users/icmini/02luka
zsh g/reports/system/AP_IO_V31_RESTORE_AND_IMPROVE_SCRIPT.zsh
```

**Or Manual Restore:**
```bash
cd /Users/icmini/02luka
git checkout fb6d88f86114dfa23b74d6b4156faa41ad10677f -- \
  tools/ap_io_v31/ \
  schemas/ap_io_v31*.json \
  docs/AP_IO_V31*.md \
  agents/*/ap_io_v31_integration.zsh \
  tests/ap_io_v31/ \
  tools/run_ap_io_v31_tests.zsh

chmod +x tools/ap_io_v31/*.zsh tests/ap_io_v31/*.zsh tools/run_ap_io_v31_tests.zsh
```

---

## Step 2: Run Test Suite

```bash
cd /Users/icmini/02luka
tools/run_ap_io_v31_tests.zsh
```

**Expected:** All tests should pass or failures documented.

---

## Step 3: Verify Test Isolation

**Check:**
```bash
grep -n "LEDGER_BASE_DIR\|mktemp.*-d" tests/ap_io_v31/*.zsh
```

**Should see:** Tests using `mktemp -d` and `LEDGER_BASE_DIR` environment variable.

---

## Step 4: Implement Phase 2 Improvements

### 4.1: Error Handling in `writer.zsh`

**Improvements:**
1. Atomic writes (write to temp, then move)
2. Retry logic (3 retries with backoff)
3. Better error messages
4. Handle disk full errors

**Implementation:** See `AP_IO_V31_WRITER_IMPROVEMENTS.md`

---

### 4.2: Error Handling in `reader.zsh`

**Improvements:**
1. Handle missing files gracefully
2. Better error messages for invalid JSON
3. Support reading from stdin
4. Handle large files efficiently

**Implementation:** See `AP_IO_V31_READER_IMPROVEMENTS.md`

---

### 4.3: Error Handling in `validator.zsh`

**Improvements:**
1. More detailed validation errors
2. Show which field failed
3. Suggest fixes for common errors
4. Support validation of multiple files

**Implementation:** See `AP_IO_V31_VALIDATOR_IMPROVEMENTS.md`

---

### 4.4: Retry Logic

**Implementation:**
- Add retry mechanism to `writer.zsh`
- Configurable retry count (default: 3)
- Exponential backoff between retries
- Log retry attempts

---

### 4.5: Enhanced Validation

**Implementation:**
- Field-level validation
- Format string validation (ledger_id, parent_id)
- Better error messages with suggestions
- Support validation warnings (non-fatal)

---

## Step 5: Re-run Tests

After implementing improvements:
```bash
tools/run_ap_io_v31_tests.zsh
```

**Expected:** All tests still pass.

---

## Step 6: Document Results

Update:
- `AP_IO_V31_RESTORATION_COMPLETE.md` - Mark as complete
- `AP_IO_V31_IMPROVEMENTS_APPLIED.md` - Document what was improved
- `AP_IO_V31_TEST_RESULTS.md` - Document test results

---

## Files Created

✅ `AP_IO_V31_RESTORE_AND_IMPROVE_SCRIPT.zsh` - Restoration script  
✅ `AP_IO_V31_FULL_IMPLEMENTATION_STATUS.md` - Status report  
✅ `AP_IO_V31_COMPLETE_ACTION_PLAN.md` - This file  
✅ `AP_IO_V31_TEST_EXECUTION_PLAN.md` - Test plan  
✅ `AP_IO_V31_NEXT_STEPS_SUMMARY.md` - Summary

---

## Quick Start

```bash
# 1. Restore files
cd /Users/icmini/02luka
zsh g/reports/system/AP_IO_V31_RESTORE_AND_IMPROVE_SCRIPT.zsh

# 2. Run tests
tools/run_ap_io_v31_tests.zsh

# 3. Verify isolation
grep -n "LEDGER_BASE_DIR\|mktemp" tests/ap_io_v31/*.zsh

# 4. Implement improvements (see separate improvement docs)
# 5. Re-run tests
# 6. Document results
```

---

**Status:** ⚠️ Waiting for file restoration  
**Next:** Run restoration script, then proceed with improvements
