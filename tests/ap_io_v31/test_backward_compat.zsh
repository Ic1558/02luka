#!/usr/bin/env zsh
# AP/IO v3.1 Backward Compatibility Tests
# Purpose: Test backward compatibility with v1.0 format

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
READER="$REPO_ROOT/tools/ap_io_v31/reader.zsh"

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

# Test 1: Reader can read v1.0 format
test_reader_v1_format() {
  local test_ledger=$(mktemp)
  
  echo '{"ts":"2025-11-16T10:00:00+07:00","agent":"cls","event":"task_start","task_id":"wo-test","source":"gg_orchestrator","summary":"Test task"}' >> "$test_ledger"
  
  local results=$("$READER" "$test_ledger" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$results" -ge 1 ]; then
    test_pass "Reader can read v1.0 format"
  else
    test_fail "Reader failed to read v1.0 format"
  fi
  
  rm -f "$test_ledger"
}

# Test 2: Reader can read v3.1 format
test_reader_v31_format() {
  local test_ledger=$(mktemp)
  
  echo '{"protocol":"AP/IO","version":"3.1","agent":"cls","ts":"2025-11-16T10:00:00+07:00","event":{"type":"task_start"}}' >> "$test_ledger"
  
  local results=$("$READER" "$test_ledger" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$results" -ge 1 ]; then
    test_pass "Reader can read v3.1 format"
  else
    test_fail "Reader failed to read v3.1 format"
  fi
  
  rm -f "$test_ledger"
}

# Test 3: Reader can read mixed format
test_reader_mixed_format() {
  local test_ledger=$(mktemp)
  
  echo '{"ts":"2025-11-16T10:00:00+07:00","agent":"cls","event":"task_start"}' >> "$test_ledger"
  echo '{"protocol":"AP/IO","version":"3.1","agent":"cls","ts":"2025-11-16T10:01:00+07:00","event":{"type":"task_result"}}' >> "$test_ledger"
  
  local results=$("$READER" "$test_ledger" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$results" -eq 2 ]; then
    test_pass "Reader can read mixed v1.0 and v3.1 format"
  else
    test_fail "Reader failed to read mixed format: expected 2, got $results"
  fi
  
  rm -f "$test_ledger"
}

# Test 4: Reader handles v3.1 with ledger extensions
test_reader_v31_extensions() {
  local test_ledger=$(mktemp)
  
  echo '{"protocol":"AP/IO","version":"3.1","agent":"cls","ts":"2025-11-16T10:00:00+07:00","event":{"type":"task_start"}}' >> "$test_ledger"
  echo '{"protocol":"AP/IO","version":"3.1","ledger_id":"ledger-20251116-021234-cls-001","parent_id":"parent-wo-wo-test","agent":"cls","ts":"2025-11-16T10:01:00+07:00","event":{"type":"task_result"},"data":{"execution_duration_ms":1250}}' >> "$test_ledger"
  
  local results=$("$READER" "$test_ledger" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$results" -eq 2 ]; then
    test_pass "Reader handles v3.1 with ledger extensions"
  else
    test_fail "Reader failed with ledger extensions: expected 2, got $results"
  fi
  
  rm -f "$test_ledger"
}

# Run all tests
main() {
  echo "Running backward compatibility tests..."
  echo ""
  
  test_reader_v1_format
  test_reader_v31_format
  test_reader_mixed_format
  test_reader_v31_extensions
  
  echo ""
  echo "Summary: $PASS passed, $FAIL failed"
  
  if [ $FAIL -eq 0 ]; then
    exit 0
  else
    exit 1
  fi
}

main

