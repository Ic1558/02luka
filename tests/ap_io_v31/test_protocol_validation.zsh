#!/usr/bin/env zsh
# AP/IO v3.1 Protocol Validation Tests
# Purpose: Test protocol message validation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VALIDATOR="$REPO_ROOT/tools/ap_io_v31/validator.zsh"

PASS=0
FAIL=0

test_pass() {
  echo "✅ PASS: $1"
  ((PASS++))
}

test_fail() {
  echo "❌ FAIL: $1"
  ((FAIL++))
}

# Test 1: Valid message
test_valid_message() {
  local msg='{"protocol":"AP/IO","version":"3.1","agent":"cls","ts":"2025-11-17T12:00:00+07:00","event":{"type":"task_start"}}'
  if echo "$msg" | "$VALIDATOR" - >/dev/null 2>&1; then
    test_pass "Valid message accepted"
  else
    test_fail "Valid message rejected"
  fi
}

# Test 2: Invalid version
test_invalid_version() {
  local msg='{"protocol":"AP/IO","version":"2.0","agent":"cls","ts":"2025-11-17T12:00:00+07:00","event":{"type":"task_start"}}'
  if ! echo "$msg" | "$VALIDATOR" - >/dev/null 2>&1; then
    test_pass "Invalid version rejected"
  else
    test_fail "Invalid version accepted"
  fi
}

# Test 3: Invalid agent
test_invalid_agent() {
  local msg='{"protocol":"AP/IO","version":"3.1","agent":"invalid","ts":"2025-11-17T12:00:00+07:00","event":{"type":"task_start"}}'
  if ! echo "$msg" | "$VALIDATOR" - >/dev/null 2>&1; then
    test_pass "Invalid agent rejected"
  else
    test_fail "Invalid agent accepted"
  fi
}

# Test 4: Missing required field
test_missing_field() {
  local msg='{"protocol":"AP/IO","version":"3.1","agent":"cls","ts":"2025-11-17T12:00:00+07:00"}'
  if ! echo "$msg" | "$VALIDATOR" - >/dev/null 2>&1; then
    test_pass "Missing required field rejected"
  else
    test_fail "Missing required field accepted"
  fi
}

# Test 5: Valid ledger_id format
test_ledger_id_format() {
  local msg='{"protocol":"AP/IO","version":"3.1","agent":"cls","ts":"2025-11-17T12:00:00+07:00","ledger_id":"ledger-20251117-120000-cls-001","event":{"type":"task_start"}}'
  if echo "$msg" | "$VALIDATOR" - >/dev/null 2>&1; then
    test_pass "Valid ledger_id format accepted"
  else
    test_fail "Valid ledger_id format rejected"
  fi
}

# Test 6: Invalid ledger_id format
test_invalid_ledger_id() {
  local msg='{"protocol":"AP/IO","version":"3.1","agent":"cls","ts":"2025-11-17T12:00:00+07:00","ledger_id":"invalid-id","event":{"type":"task_start"}}'
  if ! echo "$msg" | "$VALIDATOR" - >/dev/null 2>&1; then
    test_pass "Invalid ledger_id format rejected"
  else
    test_fail "Invalid ledger_id format accepted"
  fi
}

# Test 7: Valid parent_id format
test_parent_id_format() {
  local msg='{"protocol":"AP/IO","version":"3.1","agent":"cls","ts":"2025-11-17T12:00:00+07:00","parent_id":"parent-wo-wo-test","event":{"type":"task_start"}}'
  if echo "$msg" | "$VALIDATOR" - >/dev/null 2>&1; then
    test_pass "Valid parent_id format accepted"
  else
    test_fail "Valid parent_id format rejected"
  fi
}

# Test 8: Invalid parent_id format
test_invalid_parent_id() {
  local msg='{"protocol":"AP/IO","version":"3.1","agent":"cls","ts":"2025-11-17T12:00:00+07:00","parent_id":"invalid-parent","event":{"type":"task_start"}}'
  if ! echo "$msg" | "$VALIDATOR" - >/dev/null 2>&1; then
    test_pass "Invalid parent_id format rejected"
  else
    test_fail "Invalid parent_id format accepted"
  fi
}

# Run all tests
main() {
  echo "Running protocol validation tests..."
  echo ""
  
  test_valid_message
  test_invalid_version
  test_invalid_agent
  test_missing_field
  test_ledger_id_format
  test_invalid_ledger_id
  test_parent_id_format
  test_invalid_parent_id
  
  echo ""
  echo "Summary: $PASS passed, $FAIL failed"
  
  if [ $FAIL -eq 0 ]; then
    exit 0
  else
    exit 1
  fi
}

main

