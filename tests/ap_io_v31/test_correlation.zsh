#!/usr/bin/env zsh
# AP/IO v3.1 Correlation Tests
# Purpose: Test correlation ID functionality

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
READER="$REPO_ROOT/tools/ap_io_v31/reader.zsh"
CORRELATION_ID="$REPO_ROOT/tools/ap_io_v31/correlation_id.zsh"

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

# Test 1: Correlation ID generator exists
test_correlation_id_exists() {
  if [ -f "$CORRELATION_ID" ] && [ -x "$CORRELATION_ID" ]; then
    test_pass "Correlation ID generator exists"
  else
    test_fail "Correlation ID generator not found"
  fi
}

# Test 2: Correlation ID format
test_correlation_id_format() {
  local corr_id=$("$CORRELATION_ID")
  if echo "$corr_id" | grep -qE '^corr-[0-9]{8}-[0-9]{3}$'; then
    test_pass "Correlation ID has correct format: $corr_id"
  else
    test_fail "Correlation ID has incorrect format: $corr_id"
  fi
}

# Test 3: Reader filters by correlation ID
test_reader_correlation_filter() {
  local test_ledger=$(mktemp)
  local corr_id="corr-20251117-001"
  
  echo "{\"protocol\":\"AP/IO\",\"version\":\"3.1\",\"agent\":\"cls\",\"ts\":\"2025-11-16T10:00:00+07:00\",\"correlation_id\":\"$corr_id\",\"event\":{\"type\":\"task_start\"}}" >> "$test_ledger"
  echo "{\"protocol\":\"AP/IO\",\"version\":\"3.1\",\"agent\":\"cls\",\"ts\":\"2025-11-16T10:01:00+07:00\",\"correlation_id\":\"$corr_id\",\"event\":{\"type\":\"task_result\"}}" >> "$test_ledger"
  echo "{\"protocol\":\"AP/IO\",\"version\":\"3.1\",\"agent\":\"cls\",\"ts\":\"2025-11-16T10:02:00+07:00\",\"correlation_id\":\"corr-20251117-002\",\"event\":{\"type\":\"task_start\"}}" >> "$test_ledger"
  
  local results=$("$READER" "$test_ledger" --correlation "$corr_id" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$results" -eq 2 ]; then
    test_pass "Reader filters by correlation ID correctly"
  else
    test_fail "Reader correlation filter failed: expected 2, got $results"
  fi
  
  rm -f "$test_ledger"
}

# Test 4: Reader filters by parent ID
test_reader_parent_filter() {
  local test_ledger=$(mktemp)
  local parent_id="parent-wo-wo-test"
  
  echo "{\"protocol\":\"AP/IO\",\"version\":\"3.1\",\"agent\":\"cls\",\"ts\":\"2025-11-16T10:00:00+07:00\",\"parent_id\":\"$parent_id\",\"event\":{\"type\":\"task_start\"}}" >> "$test_ledger"
  echo "{\"protocol\":\"AP/IO\",\"version\":\"3.1\",\"agent\":\"cls\",\"ts\":\"2025-11-16T10:01:00+07:00\",\"parent_id\":\"$parent_id\",\"event\":{\"type\":\"task_result\"}}" >> "$test_ledger"
  echo "{\"protocol\":\"AP/IO\",\"version\":\"3.1\",\"agent\":\"cls\",\"ts\":\"2025-11-16T10:02:00+07:00\",\"parent_id\":\"parent-wo-wo-other\",\"event\":{\"type\":\"task_start\"}}" >> "$test_ledger"
  
  local results=$("$READER" "$test_ledger" --parent "$parent_id" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$results" -eq 2 ]; then
    test_pass "Reader filters by parent ID correctly"
  else
    test_fail "Reader parent filter failed: expected 2, got $results"
  fi
  
  rm -f "$test_ledger"
}

# Run all tests
main() {
  echo "Running correlation tests..."
  echo ""
  
  test_correlation_id_exists
  test_correlation_id_format
  test_reader_correlation_filter
  test_reader_parent_filter
  
  echo ""
  echo "Summary: $PASS passed, $FAIL failed"
  
  if [ $FAIL -eq 0 ]; then
    exit 0
  else
    exit 1
  fi
}

main

