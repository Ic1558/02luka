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
  
  if jq empty "$SCHEMA_DIR/ap_io_v31.schema.json" >/dev/null 2>&1; then
    log_test "PASS" "Protocol schema is valid JSON"
  else
    log_test "FAIL" "Protocol schema is invalid JSON"
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
  
  if jq empty "$SCHEMA_DIR/ap_io_v31_ledger.schema.json" >/dev/null 2>&1; then
    log_test "PASS" "Ledger schema is valid JSON"
  else
    log_test "FAIL" "Ledger schema is invalid JSON"
    return 1
  fi
}

# Test 3: Writer Exists
test_writer_exists() {
  log_info "Test 3: Writer script exists"
  
  if [ -f "$TOOLS_DIR/writer.zsh" ] && [ -x "$TOOLS_DIR/writer.zsh" ]; then
    log_test "PASS" "Writer script exists and is executable"
  else
    log_test "FAIL" "Writer script missing or not executable"
    return 1
  fi
}

# Test 4: Reader Exists
test_reader_exists() {
  log_info "Test 4: Reader script exists"
  
  if [ -f "$TOOLS_DIR/reader.zsh" ] && [ -x "$TOOLS_DIR/reader.zsh" ]; then
    log_test "PASS" "Reader script exists and is executable"
  else
    log_test "FAIL" "Reader script missing or not executable"
    return 1
  fi
}

# Test 5: Validator Exists
test_validator_exists() {
  log_info "Test 5: Validator script exists"
  
  if [ -f "$TOOLS_DIR/validator.zsh" ] && [ -x "$TOOLS_DIR/validator.zsh" ]; then
    log_test "PASS" "Validator script exists and is executable"
  else
    log_test "FAIL" "Validator script missing or not executable"
    return 1
  fi
}

# Test 6: CLS Integration Script Exists
test_cls_integration_exists() {
  log_info "Test 6: CLS integration script exists"
  
  if [ -f "$AGENTS_DIR/ap_io_v31_integration.zsh" ] && [ -x "$AGENTS_DIR/ap_io_v31_integration.zsh" ]; then
    log_test "PASS" "CLS integration script exists and is executable"
  else
    log_test "FAIL" "CLS integration script missing or not executable"
    return 1
  fi
}

# Test 7: Protocol Message Validation
test_protocol_validation() {
  log_info "Test 7: Protocol message validation"
  
  local test_msg='{
    "protocol": "AP/IO",
    "version": "3.1",
    "agent": "cls",
    "ts": "2025-11-16T10:00:00+07:00",
    "event": {"type": "task_start", "task_id": "wo-test"}
  }'
  
  if echo "$test_msg" | "$TOOLS_DIR/validator.zsh" - >/dev/null 2>&1; then
    log_test "PASS" "Protocol message validation works"
  else
    log_test "FAIL" "Protocol message validation failed"
    return 1
  fi
}

# Test 8: Writer Append-Only Behavior
test_writer_append_only() {
  log_info "Test 8: Writer append-only behavior"
  
  local test_ledger_dir=$(mktemp -d)
  local test_data='{"status":"test"}'
  
  if LEDGER_BASE_DIR="$test_ledger_dir" "$TOOLS_DIR/writer.zsh" cls task_start "wo-test" "gg_orchestrator" "Test" "$test_data" >/dev/null 2>&1; then
    local ledger_file="$test_ledger_dir/cls/$(date +%Y-%m-%d).jsonl"
    if [ -f "$ledger_file" ]; then
      local line_count=$(wc -l < "$ledger_file")
      if [ "$line_count" -eq 1 ]; then
        log_test "PASS" "Writer append-only behavior correct"
        rm -rf "$test_ledger_dir"
        return 0
      fi
    fi
  fi
  
  log_test "FAIL" "Writer append-only behavior incorrect"
  rm -rf "$test_ledger_dir"
  return 1
}

# Test 9: Reader Backward Compatibility
test_reader_backward_compat() {
  log_info "Test 9: Reader backward compatibility"
  
  local test_ledger=$(mktemp)
  cat > "$test_ledger" <<EOF
{
  "ts": "2025-11-16T10:00:00+07:00",
  "agent": "cls",
  "event": "task_start",
  "task_id": "wo-test"
}
EOF
  
  if "$TOOLS_DIR/reader.zsh" "$test_ledger" >/dev/null 2>&1; then
    log_test "PASS" "Reader supports v1.0 format"
    rm -f "$test_ledger"
    return 0
  else
    log_test "FAIL" "Reader does not support v1.0 format"
    rm -f "$test_ledger"
    return 1
  fi
}

# Test 10: Correlation ID Generation
test_correlation_id() {
  log_info "Test 10: Correlation ID generation"
  
  if [ -f "$TOOLS_DIR/correlation_id.zsh" ]; then
    local id=$("$TOOLS_DIR/correlation_id.zsh" 2>/dev/null)
    if [ -n "$id" ] && echo "$id" | grep -qE '^corr-[0-9]{8}-[0-9]{3}$'; then
      log_test "PASS" "Correlation ID generation works"
    else
      log_test "FAIL" "Correlation ID generation failed"
      return 1
    fi
  else
    log_test "FAIL" "Correlation ID script not found"
    return 1
  fi
}

# Test 11: CLS Status Update
test_cls_status_update() {
  log_info "Test 11: CLS status update"
  
  local test_status_file=$(mktemp)
  local test_event='{
    "protocol": "AP/IO",
    "version": "3.1",
    "agent": "cls",
    "ts": "2025-11-16T10:00:00+07:00",
    "event": {"type": "task_start", "task_id": "wo-test"}
  }'
  
  # Mock status file location
  export REPO_ROOT="$REPO_ROOT"
  mkdir -p "$(dirname "$test_status_file")"
  
  if echo "$test_event" | "$AGENTS_DIR/ap_io_v31_integration.zsh" normal >/dev/null 2>&1; then
    log_test "PASS" "CLS status update works"
    rm -f "$test_status_file"
    return 0
  else
    log_test "FAIL" "CLS status update failed"
    rm -f "$test_status_file"
    return 1
  fi
}

# Test 12: Directory Structure
test_directory_structure() {
  log_info "Test 12: Directory structure"
  
  local missing_dirs=()
  
  [ ! -d "$SCHEMA_DIR" ] && missing_dirs+=("$SCHEMA_DIR")
  [ ! -d "$TOOLS_DIR" ] && missing_dirs+=("$TOOLS_DIR")
  [ ! -d "$AGENTS_DIR" ] && missing_dirs+=("$AGENTS_DIR")
  
  if [ ${#missing_dirs[@]} -eq 0 ]; then
    log_test "PASS" "Directory structure correct"
  else
    log_test "FAIL" "Missing directories: ${missing_dirs[*]}"
    return 1
  fi
}

# Test 13: Ledger Extension Fields - ledger_id
test_ledger_id() {
  log_info "Test 13: Ledger Extension Fields - ledger_id"
  
  if [ ! -f "$TOOLS_DIR/writer.zsh" ]; then
    log_test "FAIL" "Writer not found"
    return 1
  fi
  
  local test_ledger_dir=$(mktemp -d)
  local test_data='{"status":"test"}'
  
  if LEDGER_BASE_DIR="$test_ledger_dir" "$TOOLS_DIR/writer.zsh" cls task_start "wo-test" "gg_orchestrator" "Test" "$test_data" >/dev/null 2>&1; then
    local ledger_file="$test_ledger_dir/cls/$(date +%Y-%m-%d).jsonl"
    if [ -f "$ledger_file" ]; then
      local has_ledger_id=$(grep -c "\"ledger_id\"" "$ledger_file" 2>/dev/null || echo "0")
      if [ "$has_ledger_id" -gt 0 ]; then
        log_test "PASS" "ledger_id is generated by writer"
        rm -rf "$test_ledger_dir"
        return 0
      else
        log_test "FAIL" "ledger_id not found in ledger entry"
        rm -rf "$test_ledger_dir"
        return 1
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
}

# Test 14: Ledger Extension Fields - parent_id
test_parent_id() {
  log_info "Test 14: Ledger Extension Fields - parent_id"
  
  if [ ! -f "$TOOLS_DIR/writer.zsh" ]; then
    log_test "FAIL" "Writer not found"
    return 1
  fi
  
  local test_ledger_dir=$(mktemp -d)
  local test_data='{"status":"test"}'
  local parent_id="parent-wo-wo-test-001"
  
  if LEDGER_BASE_DIR="$test_ledger_dir" "$TOOLS_DIR/writer.zsh" cls task_start "wo-test" "gg_orchestrator" "Test" "$test_data" "$parent_id" >/dev/null 2>&1; then
    local ledger_file="$test_ledger_dir/cls/$(date +%Y-%m-%d).jsonl"
    if [ -f "$ledger_file" ]; then
      local has_parent_id=$(grep -c "\"parent_id\":\"$parent_id\"" "$ledger_file" 2>/dev/null || echo "0")
      if [ "$has_parent_id" -gt 0 ]; then
        log_test "PASS" "parent_id is supported by writer"
        rm -rf "$test_ledger_dir"
        return 0
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
  test_writer_exists
  test_reader_exists
  test_validator_exists
  test_cls_integration_exists
  test_protocol_validation
  test_writer_append_only
  test_reader_backward_compat
  test_correlation_id
  test_cls_status_update
  test_directory_structure
  test_ledger_id
  test_parent_id
  test_execution_duration_ms
  
  echo
  echo "=========================================="
  echo "Summary: $PASS passed, $FAIL failed"
  echo "=========================================="
  
  [ "$FAIL" -eq 0 ] && exit 0 || exit 1
}

main "$@"
