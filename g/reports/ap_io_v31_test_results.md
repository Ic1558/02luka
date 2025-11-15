# AP/IO v3.1 Test Results

**Date:** 2025-11-16  
**Phase:** Phase 2 - Test Validation  
**Status:** ⏳ **READY TO RUN**

---

## Test Files

### 1. `tests/ap_io_v31/cls_testcases.zsh`
**Purpose:** CLS integration tests for AP/IO v3.1 Ledger System

**Tests (15 total):**
1. Protocol Schema Validation
2. Ledger Entry Schema Validation
3. Writer Stub Exists
4. Reader Stub Exists
5. Validator Exists
6. CLS Integration Script Exists
7. Protocol Message Validation
8. Writer Append-Only Behavior
9. Reader Backward Compatibility
10. Correlation ID Generation
11. CLS Status Update
12. Directory Structure
13. **Ledger Extension Fields - ledger_id** (NEW)
14. **Ledger Extension Fields - parent_id** (NEW)
15. **Ledger Extension Fields - execution_duration_ms** (NEW)

**Run:**
```bash
tests/ap_io_v31/cls_testcases.zsh
```

---

### 2. `tests/ap_io_v31/test_protocol_validation.zsh`
**Purpose:** Protocol message validation tests

**Tests (9 total):**
1. Valid message accepted
2. Invalid protocol rejected
3. Invalid version rejected
4. Invalid agent rejected
5. Missing required field rejected
6. **Valid ledger_id format accepted** (NEW)
7. **Invalid ledger_id format rejected** (NEW)
8. **Valid parent_id format accepted** (NEW)
9. **execution_duration_ms field accepted** (NEW)

**Run:**
```bash
tests/ap_io_v31/test_protocol_validation.zsh
```

---

### 3. `tests/ap_io_v31/test_routing.zsh`
**Purpose:** Event routing functionality tests

**Tests (4 total):**
1. Single target routing works
2. Multiple targets routing works
3. Broadcast routing works
4. Priority override works

**Run:**
```bash
tests/ap_io_v31/test_routing.zsh
```

---

### 4. `tests/ap_io_v31/test_correlation.zsh`
**Purpose:** Event correlation functionality tests

**Tests (4 total):**
1. Correlation ID generation works (unique)
2. Correlation ID format correct
3. Correlation query works
4. **Parent ID correlation query works** (NEW)

**Run:**
```bash
tests/ap_io_v31/test_correlation.zsh
```

---

### 5. `tests/ap_io_v31/test_backward_compat.zsh`
**Purpose:** Backward compatibility tests

**Tests (4 total):**
1. v1.0 format supported
2. v3.1 format supported
3. Mixed format (v1.0 + v3.1) supported
4. **Extension fields are optional (backward compatible)** (NEW)

**Run:**
```bash
tests/ap_io_v31/test_backward_compat.zsh
```

---

## Test Runner

**File:** `tools/run_ap_io_v31_tests.zsh`

**Purpose:** Run all test suites and report results

**Usage:**
```bash
tools/run_ap_io_v31_tests.zsh
```

**Features:**
- Runs all test files in sequence
- Reports pass/fail for each test
- Provides summary statistics
- Lists failed tests
- Exit code 0 if all pass, 1 if any fail

---

## Running All Tests

### Option 1: Using Test Runner
```bash
tools/run_ap_io_v31_tests.zsh
```

### Option 2: Manual Loop
```bash
for test in tests/ap_io_v31/*.zsh; do
  echo "Running $test..."
  "$test" || echo "FAILED: $test"
done
```

### Option 3: Individual Tests
```bash
tests/ap_io_v31/cls_testcases.zsh
tests/ap_io_v31/test_protocol_validation.zsh
tests/ap_io_v31/test_routing.zsh
tests/ap_io_v31/test_correlation.zsh
tests/ap_io_v31/test_backward_compat.zsh
```

---

## Expected Results

### Test Coverage

**Extension Fields:**
- ✅ `ledger_id`: Format validation, generation, optional
- ✅ `parent_id`: Format validation, support, correlation, optional
- ✅ `execution_duration_ms`: Field validation, support, optional

**Backward Compatibility:**
- ✅ v1.0 format supported
- ✅ v3.1 format supported
- ✅ Mixed format supported
- ✅ Extension fields optional

**Protocol Validation:**
- ✅ Valid messages accepted
- ✅ Invalid messages rejected
- ✅ Extension field formats validated

**Correlation:**
- ✅ Correlation ID generation
- ✅ Correlation queries
- ✅ Parent ID correlation queries

---

## Prerequisites

Before running tests, ensure:

1. **Directories exist:**
   ```bash
   mkdir -p g/ledger/cls
   mkdir -p g/ledger/andy
   mkdir -p g/ledger/hybrid
   ```

2. **Tools exist:**
   - `tools/ap_io_v31/writer.zsh`
   - `tools/ap_io_v31/reader.zsh`
   - `tools/ap_io_v31/validator.zsh`
   - `tools/ap_io_v31/router.zsh`
   - `tools/ap_io_v31/correlation_id.zsh`

3. **Dependencies:**
   - `jq` (for JSON processing)
   - `zsh` (shell)

---

## Test Results

**Status:** ⏳ **PENDING EXECUTION**

**To record results:**
1. Run all tests
2. Document pass/fail for each test
3. Note any issues or failures
4. Update this document with results

---

## Next Steps

1. **Run Tests:**
   ```bash
   tools/run_ap_io_v31_tests.zsh
   ```

2. **Document Results:**
   - Record pass/fail for each test
   - Note any failures
   - Document issues

3. **Fix Failures:**
   - Identify root cause
   - Fix implementation
   - Re-run tests

4. **Verify All Pass:**
   - Ensure exit code 0
   - All tests pass
   - Ready for Phase 3

---

**Last Updated:** 2025-11-16  
**Status:** Ready for test execution
