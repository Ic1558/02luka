# AP/IO v3.1 Test Execution & Improvement Plan

**Date:** 2025-11-17  
**Status:** ⏳ **IN PROGRESS**  
**Phase:** Immediate Actions + Phase 2 Improvements

---

## Current Status

✅ **Files Restored:** 23/23  
✅ **Path Calculation:** Fixed (`router.zsh`)  
⏳ **Test Suite:** Pending execution  
⏳ **Test Isolation:** Needs verification  
⏳ **Improvements:** Pending implementation

---

## Phase 1: Immediate Actions (Before Merge)

### 1. Run Test Suite ⏳

**Command:**
```bash
cd /Users/icmini/02luka
tools/run_ap_io_v31_tests.zsh
```

**Expected Tests:**
- `tests/ap_io_v31/cls_testcases.zsh` - CLS integration tests
- `tests/ap_io_v31/test_protocol_validation.zsh` - Protocol validation
- `tests/ap_io_v31/test_routing.zsh` - Event routing
- `tests/ap_io_v31/test_correlation.zsh` - Correlation ID handling
- `tests/ap_io_v31/test_backward_compat.zsh` - v1.0 compatibility
- `tests/ap_io_v31/test_hybrid_integration.zsh` - Hybrid agent integration

**Success Criteria:**
- All tests pass
- No syntax errors
- No missing dependencies

---

### 2. Verify Test Isolation ⏳

**Check for Test Isolation Issues:**

**Files to Check:**
- `tests/ap_io_v31/cls_testcases.zsh`
- `tests/ap_io_v31/test_hybrid_integration.zsh`
- All test files that write to ledger

**Verification Steps:**
1. Check if tests use `mktemp -d` for test directories
2. Verify `LEDGER_BASE_DIR` environment variable is set
3. Ensure tests clean up temp directories
4. Verify no writes to production `g/ledger/` directory

**Expected Pattern:**
```bash
# Good: Uses test isolation
local test_ledger_dir=$(mktemp -d)
LEDGER_BASE_DIR="$test_ledger_dir" tools/ap_io_v31/writer.zsh ...
rm -rf "$test_ledger_dir"

# Bad: Writes to production
tools/ap_io_v31/writer.zsh ...  # Uses default g/ledger/
```

**Files Already Using Isolation (from grep):**
- ✅ `test_hybrid_integration.zsh` - Uses `mktemp -d` and `LEDGER_BASE_DIR`
- ✅ `cls_testcases.zsh` - Test 13, 14, 15 use isolation
- ⚠️ Need to verify all tests

---

### 3. Test Agent Integrations ⏳

**Integration Scripts to Test:**
- `agents/cls/ap_io_v31_integration.zsh`
- `agents/andy/ap_io_v31_integration.zsh`
- `agents/hybrid/ap_io_v31_integration.zsh`
- `agents/liam/ap_io_v31_integration.zsh`
- `agents/gg/ap_io_v31_integration.zsh`

**Test Approach:**
1. Source integration script
2. Call ledger write function
3. Verify entry in ledger
4. Check for errors

**Example:**
```bash
source agents/cls/ap_io_v31_integration.zsh
ap_io_v31_log "task_start" "wo-test" "Test task"
# Verify entry created
```

---

## Phase 2: Critical Improvements

### 1. Implement Test Isolation (If Needed)

**Priority:** P0 (Critical)

**Tasks:**
- [ ] Audit all test files for isolation
- [ ] Update tests that write to production ledger
- [ ] Add cleanup handlers (trap EXIT)
- [ ] Verify no production writes during tests

**Implementation:**
```bash
# Standard test isolation pattern
test_example() {
  local test_ledger_dir=$(mktemp -d)
  trap "rm -rf '$test_ledger_dir'" EXIT
  
  export LEDGER_BASE_DIR="$test_ledger_dir"
  
  # Run test
  tools/ap_io_v31/writer.zsh ...
  
  # Verify results
  # ...
  
  # Cleanup handled by trap
}
```

---

### 2. Improve Error Handling

**Priority:** P1 (Important)

**Areas to Improve:**

#### `writer.zsh`
- [ ] Add retry logic for file writes
- [ ] Better error messages with context
- [ ] Atomic writes (write to temp, then move)
- [ ] Handle disk full errors gracefully
- [ ] Validate JSON before writing

**Current Issues:**
- No retry on write failures
- No atomic write pattern
- Limited error context

**Improvements:**
```bash
# Atomic write pattern
write_entry_atomic() {
  local entry="$1"
  local ledger_file="$2"
  local temp_file="${ledger_file}.tmp.$$"
  
  # Write to temp file
  echo "$entry" >> "$temp_file" || return 1
  
  # Atomic move
  mv "$temp_file" "$ledger_file" || {
    rm -f "$temp_file"
    return 1
  }
}

# Retry logic
write_with_retry() {
  local max_retries=3
  local retry=0
  
  while [ $retry -lt $max_retries ]; do
    if write_entry_atomic "$@"; then
      return 0
    fi
    ((retry++))
    sleep 0.1
  done
  
  return 1
}
```

#### `reader.zsh`
- [ ] Handle missing files gracefully
- [ ] Better error messages for invalid JSON
- [ ] Support reading from stdin
- [ ] Handle large files efficiently

#### `validator.zsh`
- [ ] More detailed validation errors
- [ ] Show which field failed
- [ ] Suggest fixes for common errors
- [ ] Support validation of multiple files

---

### 3. Add Retry Logic for Writes

**Priority:** P1 (Important)

**Implementation:**
- Add retry mechanism to `writer.zsh`
- Configurable retry count (default: 3)
- Exponential backoff between retries
- Log retry attempts

**Code:**
```bash
# In writer.zsh
MAX_WRITE_RETRIES="${MAX_WRITE_RETRIES:-3}"
WRITE_RETRY_DELAY="${WRITE_RETRY_DELAY:-0.1}"

write_ledger_entry() {
  local entry="$1"
  local ledger_file="$2"
  local retry=0
  
  while [ $retry -lt $MAX_WRITE_RETRIES ]; do
    if echo "$entry" >> "$ledger_file" 2>/dev/null; then
      return 0
    fi
    
    ((retry++))
    if [ $retry -lt $MAX_WRITE_RETRIES ]; then
      sleep "$WRITE_RETRY_DELAY"
    fi
  done
  
  echo "❌ Failed to write ledger entry after $MAX_WRITE_RETRIES retries" >&2
  return 1
}
```

---

### 4. Enhance Schema Validation

**Priority:** P1 (Important)

**Improvements:**
- [ ] Better error messages with field paths
- [ ] Validate required fields first
- [ ] Check field types more strictly
- [ ] Validate format strings (ledger_id, parent_id)
- [ ] Support validation warnings (non-fatal)

**Enhanced Error Format:**
```json
{
  "valid": false,
  "errors": [
    {
      "field": "ledger_id",
      "path": "/ledger_id",
      "message": "Invalid format: expected 'ledger-YYYYMMDD-HHMMSS-<agent>-<seq>'",
      "value": "invalid-id",
      "suggestion": "Use format: ledger-20251117-120000-cls-001"
    }
  ]
}
```

---

## Phase 3: Important Improvements (Future)

### 1. Performance Optimization
- Stream processing for large ledger files
- Caching for frequently accessed entries
- Parallel validation for multiple files

### 2. Monitoring Integration
- Metrics collection (write count, errors, latency)
- Dashboard integration
- Health checks

### 3. Developer Experience
- CLI helpers for common operations
- Debug mode with verbose logging
- Dry-run mode for testing
- Better documentation with examples

---

## Execution Checklist

### Immediate (Before Merge)
- [ ] Run full test suite
- [ ] Verify all tests pass
- [ ] Check test isolation
- [ ] Test agent integrations
- [ ] Document any failures

### Phase 2 (After Merge)
- [ ] Implement test isolation fixes
- [ ] Improve error handling
- [ ] Add retry logic
- [ ] Enhance validation
- [ ] Run tests again
- [ ] Update documentation

---

## Success Criteria

### Phase 1 Complete When:
- ✅ All tests pass
- ✅ No production ledger writes from tests
- ✅ Agent integrations verified
- ✅ No critical errors

### Phase 2 Complete When:
- ✅ All improvements implemented
- ✅ Tests updated and passing
- ✅ Error handling robust
- ✅ Documentation updated

---

**Next Action:** Run test suite and document results

---

**Status:** ⏳ Ready for execution  
**Updated:** 2025-11-17
