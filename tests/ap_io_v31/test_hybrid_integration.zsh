#!/usr/bin/env zsh
# AP/IO v3.1 Hybrid Integration Test
# Purpose: Test Hybrid WO wrapper integration with AP/IO v3.1 ledger

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# tests/ap_io_v31 -> tests -> repo root
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WRAPPER="$REPO_ROOT/tools/hybrid_wo_wrapper.zsh"
WRITER="$REPO_ROOT/tools/ap_io_v31/writer.zsh"
READER="$REPO_ROOT/tools/ap_io_v31/reader.zsh"
VALIDATOR="$REPO_ROOT/tools/ap_io_v31/validator.zsh"

PASS=0
FAIL=0

log_test() {
  local status=$1
  local msg=$2
  if [ "$status" = "PASS" ]; then
    echo "✅ PASS: $msg"
    ((PASS++))
  else
    echo "❌ FAIL: $msg"
    ((FAIL++))
  fi
}

# Test 1: Wrapper creates task_start event
test_wrapper_task_start() {
  local test_ledger_dir=$(mktemp -d)
  local test_wo_id="wo-test-$(date +%s)"
  
  # Run wrapper with a simple command
  if LEDGER_BASE_DIR="$test_ledger_dir" CORRELATION_ID="" \
     "$WRAPPER" "$test_wo_id" --exec "sleep" --args "0.1" >/dev/null 2>&1; then
    
    local ledger_file="$test_ledger_dir/hybrid/$(date +%Y-%m-%d).jsonl"
    if [[ -f "$ledger_file" ]]; then
      local has_start=$(grep -c "\"event\".*\"type\".*\"task_start\"" "$ledger_file" 2>/dev/null || echo "0")
      if [[ "$has_start" -gt 0 ]]; then
        log_test "PASS" "Wrapper creates task_start event"
      else
        log_test "FAIL" "task_start event not found in ledger"
        rm -rf "$test_ledger_dir"
        return 1
      fi
    else
      log_test "FAIL" "Ledger file not created"
      rm -rf "$test_ledger_dir"
      return 1
    fi
  else
    log_test "FAIL" "Wrapper execution failed"
    rm -rf "$test_ledger_dir"
    return 1
  fi
  
  rm -rf "$test_ledger_dir"
}

# Test 2: Wrapper creates task_result event
test_wrapper_task_result() {
  local test_ledger_dir=$(mktemp -d)
  local test_wo_id="wo-test-$(date +%s)"
  
  # Run wrapper
  LEDGER_BASE_DIR="$test_ledger_dir" CORRELATION_ID="" \
    "$WRAPPER" "$test_wo_id" --exec "true" >/dev/null 2>&1
  
  local ledger_file="$test_ledger_dir/hybrid/$(date +%Y-%m-%d).jsonl"
  if [[ -f "$ledger_file" ]]; then
    local has_result=$(grep -c "\"event\".*\"type\".*\"task_result\"" "$ledger_file" 2>/dev/null || echo "0")
    if [[ "$has_result" -gt 0 ]]; then
      log_test "PASS" "Wrapper creates task_result event"
    else
      log_test "FAIL" "task_result event not found"
      rm -rf "$test_ledger_dir"
      return 1
    fi
  else
    log_test "FAIL" "Ledger file not created"
    rm -rf "$test_ledger_dir"
    return 1
  fi
  
  rm -rf "$test_ledger_dir"
}

# Test 3: Correlation ID is consistent
test_correlation_id_consistency() {
  local test_ledger_dir=$(mktemp -d)
  local test_wo_id="wo-test-$(date +%s)"
  
  # Run wrapper
  LEDGER_BASE_DIR="$test_ledger_dir" CORRELATION_ID="" \
    "$WRAPPER" "$test_wo_id" --exec "true" >/dev/null 2>&1
  
  local ledger_file="$test_ledger_dir/hybrid/$(date +%Y-%m-%d).jsonl"
  if [[ -f "$ledger_file" ]] && command -v jq >/dev/null 2>&1; then
    local start_corr=$(jq -r 'select(.event.type=="task_start") | .correlation_id' "$ledger_file" 2>/dev/null | head -1)
    local result_corr=$(jq -r 'select(.event.type=="task_result") | .correlation_id' "$ledger_file" 2>/dev/null | head -1)
    
    if [[ -n "$start_corr" ]] && [[ -n "$result_corr" ]] && [[ "$start_corr" == "$result_corr" ]]; then
      log_test "PASS" "Correlation ID is consistent between start and result"
    else
      log_test "FAIL" "Correlation IDs don't match: start=$start_corr, result=$result_corr"
      rm -rf "$test_ledger_dir"
      return 1
    fi
  else
    log_test "FAIL" "Cannot verify correlation ID (ledger file missing or jq not available)"
    rm -rf "$test_ledger_dir"
    return 1
  fi
  
  rm -rf "$test_ledger_dir"
}

# Test 4: execution_duration_ms is positive
test_execution_duration() {
  local test_ledger_dir=$(mktemp -d)
  local test_wo_id="wo-test-$(date +%s)"
  
  # Run wrapper with a delay
  LEDGER_BASE_DIR="$test_ledger_dir" CORRELATION_ID="" \
    "$WRAPPER" "$test_wo_id" --exec "sleep" --args "0.2" >/dev/null 2>&1
  
  local ledger_file="$test_ledger_dir/hybrid/$(date +%Y-%m-%d).jsonl"
  if [[ -f "$ledger_file" ]] && command -v jq >/dev/null 2>&1; then
    local duration=$(jq -r 'select(.event.type=="task_result") | .data.execution_duration_ms' "$ledger_file" 2>/dev/null | head -1)
    
    if [[ -n "$duration" ]] && [[ "$duration" =~ ^[0-9]+$ ]] && [[ "$duration" -gt 0 ]]; then
      log_test "PASS" "execution_duration_ms is positive: ${duration}ms"
    else
      log_test "FAIL" "execution_duration_ms invalid or missing: $duration"
      rm -rf "$test_ledger_dir"
      return 1
    fi
  else
    log_test "FAIL" "Cannot verify execution_duration_ms"
    rm -rf "$test_ledger_dir"
    return 1
  fi
  
  rm -rf "$test_ledger_dir"
}

# Test 5: parent_id format is correct
test_parent_id_format() {
  local test_ledger_dir=$(mktemp -d)
  local test_wo_id="wo-test-$(date +%s)"
  
  # Run wrapper
  LEDGER_BASE_DIR="$test_ledger_dir" CORRELATION_ID="" \
    "$WRAPPER" "$test_wo_id" --exec "true" >/dev/null 2>&1
  
  local ledger_file="$test_ledger_dir/hybrid/$(date +%Y-%m-%d).jsonl"
  if [[ -f "$ledger_file" ]] && command -v jq >/dev/null 2>&1; then
    local parent_id=$(jq -r 'select(.event.type=="task_start") | .parent_id' "$ledger_file" 2>/dev/null | head -1)
    
    if [[ -n "$parent_id" ]] && [[ "$parent_id" =~ ^parent-wo- ]]; then
      log_test "PASS" "parent_id format is correct: $parent_id"
    else
      log_test "FAIL" "parent_id format invalid: $parent_id"
      rm -rf "$test_ledger_dir"
      return 1
    fi
  else
    log_test "FAIL" "Cannot verify parent_id format"
    rm -rf "$test_ledger_dir"
    return 1
  fi
  
  rm -rf "$test_ledger_dir"
}

# Test 6: Schema validation passes
test_schema_validation() {
  local test_ledger_dir=$(mktemp -d)
  local test_wo_id="wo-test-$(date +%s)"
  
  # Run wrapper
  LEDGER_BASE_DIR="$test_ledger_dir" CORRELATION_ID="" \
    "$WRAPPER" "$test_wo_id" --exec "true" >/dev/null 2>&1
  
  local ledger_file="$test_ledger_dir/hybrid/$(date +%Y-%m-%d).jsonl"
  if [[ -f "$ledger_file" ]] && [[ -f "$VALIDATOR" ]]; then
    local valid_count=0
    local total_count=0
    
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      ((total_count++))
      if echo "$line" | "$VALIDATOR" - >/dev/null 2>&1; then
        ((valid_count++))
      fi
    done < "$ledger_file"
    
    if [[ $valid_count -eq $total_count ]] && [[ $total_count -gt 0 ]]; then
      log_test "PASS" "All ledger entries pass schema validation ($valid_count/$total_count)"
    else
      log_test "FAIL" "Schema validation failed: $valid_count/$total_count valid"
      rm -rf "$test_ledger_dir"
      return 1
    fi
  else
    log_test "FAIL" "Cannot run schema validation (ledger file or validator missing)"
    rm -rf "$test_ledger_dir"
    return 1
  fi
  
  rm -rf "$test_ledger_dir"
}

# Main test runner
main() {
  echo "=========================================="
  echo "AP/IO v3.1 Hybrid Integration Tests"
  echo "=========================================="
  echo ""
  
  test_wrapper_task_start
  test_wrapper_task_result
  test_correlation_id_consistency
  test_execution_duration
  test_parent_id_format
  test_schema_validation
  
  echo ""
  echo "=========================================="
  echo "Summary: $PASS passed, $FAIL failed"
  echo "=========================================="
  
  [ "$FAIL" -eq 0 ] && exit 0 || exit 1
}

main "$@"

