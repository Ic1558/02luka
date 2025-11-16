#!/usr/bin/env zsh
# CLS Testcases for AP/IO v3.1 Ledger System
# Purpose: Validate CLS integration with AP/IO v3.1 protocol

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# tests/ap_io_v31 -> tests -> repo root
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_DIR="$SCRIPT_DIR"
SCHEMA_DIR="$REPO_ROOT/schemas"
TOOLS_DIR="$REPO_ROOT/tools/ap_io_v31"
AGENTS_DIR="$REPO_ROOT/agents/cls"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS=0
FAIL=0

log_test() {
  local test_status=$1
  local msg=$2
  if [ "$test_status" = "PASS" ]; then
    echo -e "${GREEN}✅ PASS${NC}: $msg"
    ((PASS++))
  else
    echo -e "${RED}❌ FAIL${NC}: $msg"
    ((FAIL++))
  fi
}

log_info() {
  echo -e "${YELLOW}ℹ️  INFO${NC}: $1"
}

# Test 1: Protocol Schema Validation
test_protocol_schema() {
  log_info "Test 1: Protocol Schema Validation"
  
  if [ ! -f "$SCHEMA_DIR/ap_io_v31.schema.json" ]; then
    log_test "FAIL" "Protocol schema not found"
    return 1
  fi
  
  if command -v jq >/dev/null 2>&1; then
    if jq empty "$SCHEMA_DIR/ap_io_v31.schema.json" 2>/dev/null; then
      log_test "PASS" "Protocol schema is valid JSON"
    else
      log_test "FAIL" "Protocol schema is invalid JSON"
      return 1
    fi
  else
    log_test "FAIL" "jq not found (required for schema validation)"
    return 1
  fi
}

# Test 2: Ledger Entry Schema Validation
test_ledger_schema() {
  log_info "Test 2: Ledger Entry Schema Validation"
  
  if [ ! -f "$SCHEMA_DIR/ap_io_v31_ledger.schema.json" ]; then
    log_test "FAIL" "Ledger schema not found"
    return 1
  fi
  
  if command -v jq >/dev/null 2>&1; then
    if jq empty "$SCHEMA_DIR/ap_io_v31_ledger.schema.json" 2>/dev/null; then
      log_test "PASS" "Ledger schema is valid JSON"
    else
      log_test "FAIL" "Ledger schema is invalid JSON"
      return 1
    fi
  else
    log_test "FAIL" "jq not found"
    return 1
  fi
}

# Test 3: Writer Stub Exists
test_writer_stub() {
  log_info "Test 3: Writer Stub Exists"
  
  if [ ! -f "$TOOLS_DIR/writer.zsh" ]; then
    log_test "FAIL" "Writer stub not found"
    return 1
  fi
  
  if [ -x "$TOOLS_DIR/writer.zsh" ]; then
    log_test "PASS" "Writer stub exists and is executable"
  else
    log_test "FAIL" "Writer stub exists but not executable"
    return 1
  fi
}

# Test 4: Writer Creates Ledger Entry (with test isolation)
test_writer_creates_entry() {
  log_info "Test 4: Writer Creates Ledger Entry"
  
  # Use isolated test directory
  local test_ledger_dir=$(mktemp -d)
  trap "rm -rf '$test_ledger_dir'" EXIT
  
  local test_data='{"test":"data"}'
  
  if LEDGER_BASE_DIR="$test_ledger_dir" "$TOOLS_DIR/writer.zsh" cls task_start "wo-test" "gg_orchestrator" "Test" "$test_data" >/dev/null 2>&1; then
    local ledger_file="$test_ledger_dir/cls/$(date +%Y-%m-%d).jsonl"
    if [ -f "$ledger_file" ]; then
      local entry_count=$(wc -l < "$ledger_file" | tr -d ' ')
      if [ "$entry_count" -ge 1 ]; then
        log_test "PASS" "Writer creates ledger entry"
      else
        log_test "FAIL" "Ledger file exists but is empty"
        return 1
      fi
    else
      log_test "FAIL" "Ledger file not created"
      return 1
    fi
  else
    log_test "FAIL" "Writer failed to create entry"
    return 1
  fi
}

# Test 5: Ledger ID Generation
test_ledger_id_generation() {
  log_info "Test 5: Ledger ID Generation"
  
  # Use isolated test directory
  local test_ledger_dir=$(mktemp -d)
  trap "rm -rf '$test_ledger_dir'" EXIT
  
  local test_data='{"test":"ledger_id"}'
  
  if LEDGER_BASE_DIR="$test_ledger_dir" "$TOOLS_DIR/writer.zsh" cls task_start "wo-test" "gg_orchestrator" "Test" "$test_data" "" "" >/dev/null 2>&1; then
    local ledger_file="$test_ledger_dir/cls/$(date +%Y-%m-%d).jsonl"
    if [ -f "$ledger_file" ]; then
      local ledger_id=$(jq -r '.ledger_id' "$ledger_file" 2>/dev/null | head -1)
      if echo "$ledger_id" | grep -qE '^ledger-[0-9]{8}-[0-9]{6}-cls-[0-9]{3}$'; then
        log_test "PASS" "Ledger ID has correct format: $ledger_id"
      else
        log_test "FAIL" "Ledger ID has incorrect format: $ledger_id"
        return 1
      fi
    else
      log_test "FAIL" "Ledger file not created"
      return 1
    fi
  else
    log_test "FAIL" "Writer failed"
    return 1
  fi
}

# Test 6: Parent ID Support
test_parent_id() {
  log_info "Test 6: Parent ID Support"
  
  # Use isolated test directory
  local test_ledger_dir=$(mktemp -d)
  trap "rm -rf '$test_ledger_dir'" EXIT
  
  local parent_id="parent-wo-wo-test"
  local test_data='{"test":"parent_id"}'
  
  if LEDGER_BASE_DIR="$test_ledger_dir" "$TOOLS_DIR/writer.zsh" cls task_start "wo-test" "gg_orchestrator" "Test" "$test_data" "$parent_id" >/dev/null 2>&1; then
    local ledger_file="$test_ledger_dir/cls/$(date +%Y-%m-%d).jsonl"
    if [ -f "$ledger_file" ]; then
      local found_parent_id=$(jq -r '.parent_id' "$ledger_file" 2>/dev/null | head -1)
      if [ "$found_parent_id" = "$parent_id" ]; then
        log_test "PASS" "Parent ID correctly stored: $parent_id"
      else
        log_test "FAIL" "Parent ID mismatch: expected $parent_id, got $found_parent_id"
        return 1
      fi
    else
      log_test "FAIL" "Ledger file not created"
      return 1
    fi
  else
    log_test "FAIL" "Writer failed"
    return 1
  fi
}

# Test 7: Execution Duration Support
test_execution_duration_ms() {
  log_info "Test 7: Execution Duration Support"
  
  # Test isolation: use temporary ledger directory
  local test_ledger_dir=$(mktemp -d)
  trap "rm -rf '$test_ledger_dir'" EXIT
  
  local duration_ms=1250
  local test_data='{"test":"duration"}'
  
  if LEDGER_BASE_DIR="$test_ledger_dir" "$TOOLS_DIR/writer.zsh" cls task_result "wo-test" "gg_orchestrator" "Test" "$test_data" "" "$duration_ms" >/dev/null 2>&1; then
    local ledger_file="$test_ledger_dir/cls/$(date +%Y-%m-%d).jsonl"
    if [ -f "$ledger_file" ]; then
      local found_duration=$(jq -r '.execution_duration_ms' "$ledger_file" 2>/dev/null | head -1)
      if [ "$found_duration" = "$duration_ms" ]; then
        log_test "PASS" "Execution duration correctly stored: ${duration_ms}ms"
      else
        log_test "FAIL" "Execution duration mismatch: expected $duration_ms, got $found_duration"
        return 1
      fi
    else
      log_test "FAIL" "Ledger file not created"
      return 1
    fi
  else
    log_test "FAIL" "Writer failed"
    return 1
  fi
}

# Test 8: Reader Can Read Entries
test_reader_reads_entries() {
  log_info "Test 8: Reader Can Read Entries"
  
  # Use isolated test directory
  local test_ledger_dir=$(mktemp -d)
  trap "rm -rf '$test_ledger_dir'" EXIT
  
  # Write test entry
  LEDGER_BASE_DIR="$test_ledger_dir" "$TOOLS_DIR/writer.zsh" cls task_start "wo-test" "gg_orchestrator" "Test" >/dev/null 2>&1
  
  local ledger_file="$test_ledger_dir/cls/$(date +%Y-%m-%d).jsonl"
  if [ -f "$ledger_file" ]; then
    if "$TOOLS_DIR/reader.zsh" "$ledger_file" >/dev/null 2>&1; then
      log_test "PASS" "Reader can read ledger entries"
    else
      log_test "FAIL" "Reader failed to read entries"
      return 1
    fi
  else
    log_test "FAIL" "Ledger file not created"
    return 1
  fi
}

# Test 9: Validator Validates Entries
test_validator_validates() {
  log_info "Test 9: Validator Validates Entries"
  
  # Create valid test entry
  local test_entry='{"protocol":"AP/IO","version":"3.1","agent":"cls","ts":"2025-11-17T12:00:00+07:00","event":{"type":"task_start"}}'
  
  if echo "$test_entry" | "$TOOLS_DIR/validator.zsh" - >/dev/null 2>&1; then
    log_test "PASS" "Validator accepts valid entry"
  else
    log_test "FAIL" "Validator rejected valid entry"
    return 1
  fi
  
  # Test invalid entry
  local invalid_entry='{"protocol":"AP/IO","version":"2.0","agent":"cls","ts":"2025-11-17T12:00:00+07:00","event":{"type":"task_start"}}'
  
  if ! echo "$invalid_entry" | "$TOOLS_DIR/validator.zsh" - >/dev/null 2>&1; then
    log_test "PASS" "Validator rejects invalid entry"
  else
    log_test "FAIL" "Validator accepted invalid entry"
    return 1
  fi
}

# Test 10: CLS Integration Script Exists
test_cls_integration() {
  log_info "Test 10: CLS Integration Script Exists"
  
  if [ ! -f "$AGENTS_DIR/ap_io_v31_integration.zsh" ]; then
    log_test "FAIL" "CLS integration script not found"
    return 1
  fi
  
  if [ -x "$AGENTS_DIR/ap_io_v31_integration.zsh" ]; then
    log_test "PASS" "CLS integration script exists and is executable"
  else
    log_test "FAIL" "CLS integration script exists but not executable"
    return 1
  fi
}

# Run all tests
main() {
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║     CLS AP/IO v3.1 Test Cases                                 ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo ""
  
  test_protocol_schema
  test_ledger_schema
  test_writer_stub
  test_writer_creates_entry
  test_ledger_id_generation
  test_parent_id
  test_execution_duration_ms
  test_reader_reads_entries
  test_validator_validates
  test_cls_integration
  
  echo ""
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║     Test Summary                                              ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo ""
  echo "Passed: $PASS"
  echo "Failed: $FAIL"
  echo ""
  
  if [ $FAIL -eq 0 ]; then
    echo "✅ All tests passed!"
    exit 0
  else
    echo "❌ Some tests failed"
    exit 1
  fi
}

main

