# AP/IO v3.1 Test Execution

**Date:** 2025-11-16  
**Status:** Test Suite Ready for Execution

---

## Test Runner

**File:** `tools/run_ap_io_v31_tests.zsh`

### Usage

```bash
# Run full test suite
tools/run_ap_io_v31_tests.zsh
```

### Test Files

The test runner executes these files in order:

1. `test_protocol_validation.zsh` - Protocol validation tests
2. `test_routing.zsh` - Routing tests
3. `test_correlation.zsh` - Correlation tests
4. `test_backward_compat.zsh` - Backward compatibility tests
5. `cls_testcases.zsh` - CLS integration tests

### Expected Output

```
==========================================
AP/IO v3.1 Test Suite Runner
==========================================

Test Directory: /path/to/tests/ap_io_v31
Test Files: 5

--- Running: test_protocol_validation.zsh ---
✅ PASS: test_protocol_validation.zsh

--- Running: test_routing.zsh ---
✅ PASS: test_routing.zsh

... (more tests) ...

==========================================
Test Summary
==========================================
Passed: 5
Failed: 0
Total:  5

✅ All tests passed!
```

### Exit Codes

- **0**: All tests passed
- **1**: One or more tests failed

---

## Manual Test Execution

If the test runner doesn't produce output, you can run tests individually:

```bash
# CLS test cases (15 tests)
tests/ap_io_v31/cls_testcases.zsh

# Protocol validation (10 tests)
tests/ap_io_v31/test_protocol_validation.zsh

# Routing tests (4 tests)
tests/ap_io_v31/test_routing.zsh

# Correlation tests (4 tests)
tests/ap_io_v31/test_correlation.zsh

# Backward compatibility (4 tests)
tests/ap_io_v31/test_backward_compat.zsh
```

---

## Troubleshooting

### No Output from Test Runner

If the test runner produces no output:

1. **Check file permissions:**
   ```bash
   chmod +x tools/run_ap_io_v31_tests.zsh
   chmod +x tests/ap_io_v31/*.zsh
   ```

2. **Check syntax:**
   ```bash
   zsh -n tools/run_ap_io_v31_tests.zsh
   ```

3. **Run with explicit shell:**
   ```bash
   /bin/zsh tools/run_ap_io_v31_tests.zsh
   ```

4. **Check test files exist:**
   ```bash
   ls -la tests/ap_io_v31/*.zsh
   ```

5. **Run individual tests:**
   ```bash
   tests/ap_io_v31/cls_testcases.zsh
   ```

### Missing Dependencies

The test runner checks for:
- `tools/ap_io_v31/validator.zsh`
- `tools/ap_io_v31/correlation_id.zsh`
- `tools/ap_io_v31/router.zsh`

If any are missing, warnings will be displayed.

---

## Test Results

**Status:** Ready for execution

To capture test results:

```bash
# Run and save output
tools/run_ap_io_v31_tests.zsh > test_results.txt 2>&1

# Or run individual tests
tests/ap_io_v31/cls_testcases.zsh > cls_test_results.txt 2>&1
```

---

**Test Suite Ready** ✅  
**Execute:** `tools/run_ap_io_v31_tests.zsh`
