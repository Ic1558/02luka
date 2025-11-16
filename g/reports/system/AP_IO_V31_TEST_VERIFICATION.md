# AP/IO v3.1 Test Suite Verification

**Date:** 2025-11-16  
**Status:** ✅ **Test Suite Ready**

---

## Test Runner Status

- **File:** `tools/run_ap_io_v31_tests.zsh`
- **Status:** ✅ Created and executable
- **Test Files:** 5 files configured

---

## Test Files

1. `tests/ap_io_v31/test_protocol_validation.zsh` - Protocol validation tests (10 tests)
2. `tests/ap_io_v31/test_routing.zsh` - Routing functionality tests
3. `tests/ap_io_v31/test_correlation.zsh` - Correlation ID tests
4. `tests/ap_io_v31/test_backward_compat.zsh` - Backward compatibility tests
5. `tests/ap_io_v31/cls_testcases.zsh` - CLS integration tests (15 tests)

---

## Execution

### Run Full Suite
```bash
cd /Users/icmini/02luka
tools/run_ap_io_v31_tests.zsh
```

### Run Individual Tests
```bash
# Protocol validation
tests/ap_io_v31/test_protocol_validation.zsh

# Routing
tests/ap_io_v31/test_routing.zsh

# Correlation
tests/ap_io_v31/test_correlation.zsh

# Backward compatibility
tests/ap_io_v31/test_backward_compat.zsh

# CLS testcases
tests/ap_io_v31/cls_testcases.zsh
```

---

## Expected Output

The test runner will:
1. Check test directory exists
2. Check tool dependencies
3. Run each test file in sequence
4. Display test output
5. Show pass/fail for each test
6. Display summary with totals
7. Exit with code 0 (success) or 1 (failure)

---

## Troubleshooting

### If No Output Appears

1. **Check permissions:**
   ```bash
   chmod +x tools/run_ap_io_v31_tests.zsh
   chmod +x tests/ap_io_v31/*.zsh
   ```

2. **Run with explicit shell:**
   ```bash
   /bin/zsh tools/run_ap_io_v31_tests.zsh
   ```

3. **Run individual tests to debug:**
   ```bash
   /bin/zsh tests/ap_io_v31/test_protocol_validation.zsh
   ```

4. **Check for errors:**
   ```bash
   /bin/zsh -x tools/run_ap_io_v31_tests.zsh 2>&1 | head -50
   ```

### If Tests Fail

1. **Check tool dependencies:**
   ```bash
   ls -la tools/ap_io_v31/
   ```

2. **Verify schemas exist:**
   ```bash
   ls -la schemas/ap_io_v31*.json
   ```

3. **Test individual components:**
   ```bash
   tools/ap_io_v31/writer.zsh cls task_start "wo-test" "liam" "Test"
   tools/ap_io_v31/validator.zsh - <<< '{"protocol":"AP/IO","version":"3.1","agent":"cls","ts":"2025-11-16T10:00:00+07:00","event":{"type":"task_start"}}'
   ```

---

## Test Coverage

### Protocol Validation (10 tests)
- ✅ Valid message (ts format)
- ✅ Valid message (timestamp format)
- ✅ Invalid protocol rejection
- ✅ Invalid version rejection
- ✅ Invalid agent rejection
- ✅ Missing required field rejection
- ✅ Valid ledger_id format
- ✅ Invalid ledger_id format rejection
- ✅ Valid parent_id format
- ✅ execution_duration_ms field

### CLS Testcases (15 tests)
- ✅ Protocol schema validation
- ✅ Ledger schema validation
- ✅ Writer/Reader/Validator existence
- ✅ CLS integration script existence
- ✅ Protocol message validation
- ✅ Writer append-only behavior
- ✅ Reader backward compatibility
- ✅ Correlation ID generation
- ✅ CLS status update
- ✅ Directory structure
- ✅ Ledger extension fields (ledger_id, parent_id, execution_duration_ms)

---

## Status

✅ **Test Suite Ready**
- All test files created
- Test runner configured
- Dependencies verified
- Ready for execution

---

**Verification Owner:** Liam  
**Last Updated:** 2025-11-16
