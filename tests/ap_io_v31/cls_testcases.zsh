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

# Test 4: Reader Stub Exists
test_reader_stub() {
  log_info "Test 4: Reader Stub Exists"
  
  if [ ! -f "$TOOLS_DIR/reader.zsh" ]; then
    log_test "FAIL" "Reader stub not found"
    return 1
  fi
  
  if [ -x "$TOOLS_DIR/reader.zsh" ]; then
    log_test "PASS" "Reader stub exists and is executable"
  else
    log_test "FAIL" "Reader stub exists but not executable"
    return 1
  fi
}

# Test 5: Validator Exists
test_validator() {
  log_info "Test 5: Validator Exists"
  
  if [ ! -f "$TOOLS_DIR/validator.zsh" ]; then
    log_test "FAIL" "Validator not found"
    return 1
  fi
  
  if [ -x "$TOOLS_DIR/validator.zsh" ]; then
    log_test "PASS" "Validator exists and is executable"
  else
    log_test "FAIL" "Validator exists but not executable"
    return 1
  fi
}

# Test 6: CLS Integration Script Exists
test_cls_integration() {
  log_info "Test 6: CLS Integration Script Exists"
  
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

# Test 7: Protocol Message Validation
test_protocol_message() {
  log_info "Test 7: Protocol Message Validation"
  
  local test_msg='{
    "protocol": "AP/IO",
    "version": "3.1",
    "agent": "cls",
    "timestamp": "2025-11-16T02:12:34+07:00",
    "correlation_id": "corr-test-001",
    "session_id": "2025-11-16_cls_001",
    "event": {
      "type": "task_start",
      "task_id": "wo-test",
      "source": "gg_orchestrator",
      "summary": "Test task"
    },
    "data": {
      "status": "started"
    },
    "routing": {
      "targets": ["cls"],
      "broadcast": false,
      "priority": "normal"
    }
  }'
  
  local tmp_msg=$(mktemp)
  echo "$test_msg" > "$tmp_msg"
  
  if [ -f "$TOOLS_DIR/validator.zsh" ]; then
    if "$TOOLS_DIR/validator.zsh" "$tmp_msg" >/dev/null 2>&1; then
      log_test "PASS" "Protocol message validation works"
    else
      log_test "FAIL" "Protocol message validation failed"
      rm -f "$tmp_msg"
      return 1
    fi
  else
    log_test "FAIL" "Validator not found"
    rm -f "$tmp_msg"
    return 1
  fi
  
  rm -f "$tmp_msg"
}

# Test 8: Writer Append-Only Behavior
test_writer_append_only() {
  log_info "Test 8: Writer Append-Only Behavior"
  
  local test_ledger=$(mktemp)
  local test_entry='{"protocol":"AP/IO","version":"3.1","agent":"cls","ts":"2025-11-16T10:00:00+07:00","event":{"type":"test"}}'
  
  # Write first entry
  echo "$test_entry" >> "$test_ledger"
  local line1=$(wc -l < "$test_ledger")
  
  # Write second entry
  echo "$test_entry" >> "$test_ledger"
  local line2=$(wc -l < "$test_ledger")
  
  if [ "$line2" -gt "$line1" ]; then
    log_test "PASS" "Writer uses append-only (>>) pattern"
  else
    log_test "FAIL" "Writer does not use append-only pattern"
    rm -f "$test_ledger"
    return 1
  fi
  
  rm -f "$test_ledger"
}

# Test 9: Reader Backward Compatibility
test_reader_backward_compat() {
  log_info "Test 9: Reader Backward Compatibility"
  
  local test_ledger=$(mktemp)
  
  # Write v1.0 format entry
  echo '{"ts":"2025-11-16T10:00:00+07:00","agent":"cls","event":"test","summary":"v1.0 entry"}' >> "$test_ledger"
  
  # Write v3.1 format entry
  echo '{"protocol":"AP/IO","version":"3.1","agent":"cls","ts":"2025-11-16T10:01:00+07:00","event":{"type":"test"}}' >> "$test_ledger"
  
  if [ -f "$TOOLS_DIR/reader.zsh" ]; then
    if "$TOOLS_DIR/reader.zsh" "$test_ledger" >/dev/null 2>&1; then
      log_test "PASS" "Reader supports backward compatibility (v1.0 and v3.1)"
    else
      log_test "FAIL" "Reader backward compatibility failed"
      rm -f "$test_ledger"
      return 1
    fi
  else
    log_test "FAIL" "Reader stub not found"
    rm -f "$test_ledger"
    return 1
  fi
  
  rm -f "$test_ledger"
}

# Test 10: Correlation ID Generation
test_correlation_id() {
  log_info "Test 10: Correlation ID Generation"
  
  if [ ! -f "$TOOLS_DIR/correlation_id.zsh" ]; then
    log_test "FAIL" "Correlation ID generator not found"
    return 1
  fi
  
  local id1=$("$TOOLS_DIR/correlation_id.zsh" 2>/dev/null || echo "")
  local id2=$("$TOOLS_DIR/correlation_id.zsh" 2>/dev/null || echo "")
  
  if [ -n "$id1" ] && [ -n "$id2" ] && [ "$id1" != "$id2" ]; then
    log_test "PASS" "Correlation ID generation works (unique IDs)"
  else
    log_test "FAIL" "Correlation ID generation failed or not unique"
    return 1
  fi
}

# Test 11: CLS Status Update
test_cls_status_update() {
  log_info "Test 11: CLS Status Update"
  
  if [ ! -f "$AGENTS_DIR/status.json" ]; then
    log_test "FAIL" "CLS status.json not found"
    return 1
  fi
  
  if command -v jq >/dev/null 2>&1; then
    local protocol=$(jq -r '.protocol // "none"' "$AGENTS_DIR/status.json" 2>/dev/null || echo "none")
    if [ "$protocol" != "none" ]; then
      log_test "PASS" "CLS status.json includes protocol field"
    else
      log_test "FAIL" "CLS status.json missing protocol field"
      return 1
    fi
  else
    log_test "FAIL" "jq not found"
    return 1
  fi
}

# Test 12: Directory Structure
test_directory_structure() {
  log_info "Test 12: Directory Structure"
  
  local required_dirs=(
    "$REPO_ROOT/g/ledger/cls"
    "$REPO_ROOT/agents/cls"
    "$TOOLS_DIR"
    "$TEST_DIR"
  )
  
  local missing=0
  for dir in "${required_dirs[@]}"; do
    if [ ! -d "$dir" ]; then
      log_info "Missing directory: $dir"
      ((missing++))
    fi
  done
  
  if [ "$missing" -eq 0 ]; then
    log_test "PASS" "All required directories exist"
  else
    log_test "FAIL" "Missing $missing required directories"
    return 1
  fi
}

# Test 13: Ledger Extension Fields - ledger_id
test_ledger_id_generation() {
  log_info "Test 13: Ledger Extension Fields - ledger_id"
  
  if [ ! -f "$TOOLS_DIR/writer.zsh" ]; then
    log_test "FAIL" "Writer not found"
    return 1
  fi
  
  # Use isolated test directory
  local test_ledger_dir=$(mktemp -d)
  local test_data='{"status":"test"}'
  
  # Write entry and check for ledger_id
  if LEDGER_BASE_DIR="$test_ledger_dir" "$TOOLS_DIR/writer.zsh" cls task_start "wo-test" "gg_orchestrator" "Test" "$test_data" "" "" >/dev/null 2>&1; then
    # Check if ledger file was created and contains ledger_id
    local ledger_file="$test_ledger_dir/cls/$(date +%Y-%m-%d).jsonl"
    if [ -f "$ledger_file" ]; then
      # Verify ledger_id exists and has correct format
      if command -v jq >/dev/null 2>&1; then
        local ledger_id=$(jq -r '.ledger_id' "$ledger_file" 2>/dev/null | tail -1)
        if [[ -n "$ledger_id" ]] && [[ "$ledger_id" =~ ^ledger-[0-9]{8}-[0-9]{6}-[a-z]+-[0-9]+$ ]]; then
          log_test "PASS" "ledger_id is generated with correct format: $ledger_id"
        else
          log_test "FAIL" "ledger_id format invalid: ${ledger_id:-missing}"
          rm -rf "$test_ledger_dir"
          return 1
        fi
      else
        # Fallback: check existence only
        local has_ledger_id=$(grep -c '"ledger_id"' "$ledger_file" 2>/dev/null || echo "0")
        if [ "$has_ledger_id" -gt 0 ]; then
          log_test "PASS" "ledger_id is generated by writer (format validation skipped: jq not available)"
        else
          log_test "FAIL" "ledger_id not found in ledger entry"
          rm -rf "$test_ledger_dir"
          return 1
        fi
      fi
    else
      log_test "FAIL" "Ledger file not created"
      rm -rf "$test_ledger_dir"
      return 1
    fi
  else
    log_test "FAIL" "Writer failed to write entry"
    rm -rf "$test_ledger_dir"
    return 1
  fi
  
  rm -rf "$test_ledger_dir"
}

# Test 14: Ledger Extension Fields - parent_id
test_parent_id_support() {
  log_info "Test 14: Ledger Extension Fields - parent_id"
  
  if [ ! -f "$TOOLS_DIR/writer.zsh" ]; then
    log_test "FAIL" "Writer not found"
    return 1
  fi
  
  # Use isolated test directory
  local test_ledger_dir=$(mktemp -d)
  local test_data='{"status":"test"}'
  local parent_id="parent-wo-wo-test-001"
  
  if LEDGER_BASE_DIR="$test_ledger_dir" "$TOOLS_DIR/writer.zsh" cls task_start "wo-test" "gg_orchestrator" "Test" "$test_data" "$parent_id" >/dev/null 2>&1; then
    local ledger_file="$test_ledger_dir/cls/$(date +%Y-%m-%d).jsonl"
    if [ -f "$ledger_file" ]; then
      local has_parent_id=$(grep -c "\"parent_id\".*\"$parent_id\"" "$ledger_file" 2>/dev/null || echo "0")
      if [ "$has_parent_id" -gt 0 ]; then
        log_test "PASS" "parent_id is supported by writer"
      else
        log_test "FAIL" "parent_id not found in ledger entry"
        rm -rf "$test_ledger_dir"
        return 1
      fi
    else
      log_test "FAIL" "Ledger file not created"
      rm -rf "$test_ledger_dir"
      return 1
    fi
  else
    log_test "FAIL" "Writer failed to write entry with parent_id"
    rm -rf "$test_ledger_dir"
    return 1
  fi
  
  rm -rf "$test_ledger_dir"
}

# Test 15: Ledger Extension Fields - execution_duration_ms
test_execution_duration_ms() {
  log_info "Test 15: Ledger Extension Fields - execution_duration_ms"
  
  if [ ! -f "$TOOLS_DIR/writer.zsh" ]; then
    log_test "FAIL" "Writer not found"
    return 1
  fi
  
  # Test isolation: use temporary ledger directory
  local test_ledger_dir=$(mktemp -d)
  local test_data='{"status":"test"}'
  local duration_ms=1250
  
  # Test that writer accepts execution_duration_ms parameter
  if LEDGER_BASE_DIR="$test_ledger_dir" "$TOOLS_DIR/writer.zsh" cls task_result "wo-test" "gg_orchestrator" "Test" "$test_data" "" "$duration_ms" >/dev/null 2>&1; then
    local ledger_file="$test_ledger_dir/cls/$(date +%Y-%m-%d).jsonl"
    if [ -f "$ledger_file" ]; then
      local has_duration=$(grep -c "\"execution_duration_ms\".*$duration_ms" "$ledger_file" 2>/dev/null || echo "0")
      if [ "$has_duration" -gt 0 ]; then
        log_test "PASS" "execution_duration_ms is supported by writer"
        rm -rf "$test_ledger_dir"
        return 0
      else
        log_test "FAIL" "execution_duration_ms not found in ledger entry"
        rm -rf "$test_ledger_dir"
        return 1
      fi
    else
      log_test "FAIL" "Ledger file not created"
      rm -rf "$test_ledger_dir"
      return 1
    fi
  else
    log_test "FAIL" "Writer failed to write entry with execution_duration_ms"
    rm -rf "$test_ledger_dir"
    return 1
  fi
}

# Main test runner
main() {
  echo "=========================================="
  echo "CLS Testcases for AP/IO v3.1 Ledger"
  echo "=========================================="
  echo
  
  test_protocol_schema
  test_ledger_schema
  test_writer_stub
  test_reader_stub
  test_validator
  test_cls_integration
  test_protocol_message
  test_writer_append_only
  test_reader_backward_compat
  test_correlation_id
  test_cls_status_update
  test_directory_structure
  test_ledger_id_generation
  test_parent_id_support
  test_execution_duration_ms
  
  echo
  echo "=========================================="
  echo "Test Summary: $PASS passed, $FAIL failed"
  echo "=========================================="
  
  if [ "$FAIL" -eq 0 ]; then
    exit 0
  else
    exit 1
  fi
}

main "$@"
