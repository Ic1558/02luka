# AP/IO v3.1 Post-Restoration Actions

**Date:** 2025-11-17  
**Status:** ✅ Files Restored - Ready for Verification & Improvements

---

## ✅ Restoration Complete

**Files Restored:** 23/23 from commit `fb6d88f86114dfa23b74d6b4156faa41ad10677f`

---

## Immediate Actions Required

### 1. Run Test Suite ⏳
```bash
tools/run_ap_io_v31_tests.zsh
```

**Expected:**
- All tests should pass
- No test isolation issues (should use temp directories)
- Verify no writes to production ledger

**If Tests Fail:**
- Document failures
- Fix critical issues before merge
- Update improvement report

### 2. Verify Path Calculations ⏳

**Check all scripts for consistent REPO_ROOT:**
```bash
# Should be:
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# NOT:
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"  # ❌ Wrong
```

**Files to Check:**
- `tools/ap_io_v31/writer.zsh`
- `tools/ap_io_v31/reader.zsh`
- `tools/ap_io_v31/validator.zsh`
- `tools/ap_io_v31/pretty_print.zsh`
- All agent integration scripts

### 3. Verify Test Isolation ⏳

**Check test files:**
- `tests/ap_io_v31/cls_testcases.zsh`
- All test files should use `mktemp -d` for test data

**Verify:**
```bash
grep -n "LEDGER_BASE_DIR\|mktemp" tests/ap_io_v31/*.zsh
```

**Should see:**
- `TEST_LEDGER_DIR=$(mktemp -d)`
- `export LEDGER_BASE_DIR="$TEST_LEDGER_DIR"`

---

## Quick Verification Commands

### Syntax Check
```bash
for f in tools/ap_io_v31/*.zsh; do
    zsh -n "$f" && echo "✅ $(basename $f)" || echo "❌ $(basename $f)"
done
```

### JSON Schema Validation
```bash
python3 -m json.tool schemas/ap_io_v31.schema.json > /dev/null && echo "✅ Valid" || echo "❌ Invalid"
python3 -m json.tool schemas/ap_io_v31_ledger.schema.json > /dev/null && echo "✅ Valid" || echo "❌ Invalid"
```

### Test Execution
```bash
tools/run_ap_io_v31_tests.zsh
```

### Path Calculation Check
```bash
grep -n "REPO_ROOT.*\.\." tools/ap_io_v31/*.zsh agents/*/ap_io_v31_integration.zsh
```

---

## Improvement Implementation Plan

### Phase 1: Critical Fixes (After Verification)

**1. Fix Path Calculations**
- Standardize all `REPO_ROOT` calculations
- Test from different directories
- Verify all scripts work correctly

**2. Implement Test Isolation**
- Update all test files to use temp directories
- Verify no production writes
- Add cleanup after tests

**3. Improve Error Handling**
- Add error codes
- Add retry logic for writes
- Add comprehensive logging

### Phase 2: Important Improvements

**4. Schema Validation**
- Enhance validation rules
- Add better error messages
- Add schema versioning

**5. Performance**
- Optimize write operations
- Add caching where appropriate
- Profile and optimize slow paths

### Phase 3: Nice-to-Have

**6. Monitoring**
- Add metrics collection
- Dashboard integration
- Health checks

**7. Developer Experience**
- CLI helpers
- Debug mode
- Better documentation

---

## Status Checklist

- ✅ Files restored from git history
- ⏳ Test suite execution
- ⏳ Path calculation verification
- ⏳ Test isolation verification
- ⏳ Syntax validation
- ⏳ JSON schema validation
- ⏳ Improvement implementation

---

**Next:** Run test suite and verify all checks pass before proceeding with improvements.
