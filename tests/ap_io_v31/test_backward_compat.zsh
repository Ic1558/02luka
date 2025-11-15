#!/usr/bin/env zsh
# AP/IO v3.1 Backward Compatibility Tests
# Purpose: Test support for Agent Ledger v1.0 format

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# tests/ap_io_v31 -> tests -> repo root
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
READER="$REPO_ROOT/tools/ap_io_v31/reader.zsh"

PASS=0
FAIL=0

test_v10_format() {
  # Create test ledger with v1.0 format
  local test_ledger=$(mktemp)
  
  # Write v1.0 format entry
  echo '{"ts":"2025-11-16T10:00:00+07:00","agent":"cls","event":"task_start","task_id":"wo-test","source":"gg_orchestrator","summary":"Test task"}' >> "$test_ledger"
  
  # Read with v3.1 reader
  local results=$("$READER" "$test_ledger" 2>/dev/null | wc -l)
  
  if [ "$results" -ge 1 ]; then
    echo "✅ PASS: v1.0 format supported"
    ((PASS++))
  else
    echo "❌ FAIL: v1.0 format not supported"
    ((FAIL++))
  fi
  
  rm -f "$test_ledger"
}

test_v31_format() {
  # Create test ledger with v3.1 format
  local test_ledger=$(mktemp)
  
  # Write v3.1 format entry
  echo '{"protocol":"AP/IO","version":"3.1","agent":"cls","ts":"2025-11-16T10:00:00+07:00","event":{"type":"task_start"}}' >> "$test_ledger"
  
  # Read with v3.1 reader
  local results=$("$READER" "$test_ledger" 2>/dev/null | wc -l)
  
  if [ "$results" -ge 1 ]; then
    echo "✅ PASS: v3.1 format supported"
    ((PASS++))
  else
    echo "❌ FAIL: v3.1 format not supported"
    ((FAIL++))
  fi
  
  rm -f "$test_ledger"
}

test_mixed_format() {
  # Create test ledger with mixed v1.0 and v3.1
  local test_ledger=$(mktemp)
  
  # Write v1.0 entry
  echo '{"ts":"2025-11-16T10:00:00+07:00","agent":"cls","event":"task_start"}' >> "$test_ledger"
  
  # Write v3.1 entry
  echo '{"protocol":"AP/IO","version":"3.1","agent":"cls","ts":"2025-11-16T10:01:00+07:00","event":{"type":"task_result"}}' >> "$test_ledger"
  
  # Read both
  local results=$("$READER" "$test_ledger" 2>/dev/null | wc -l)
  
  if [ "$results" -ge 2 ]; then
    echo "✅ PASS: Mixed format (v1.0 + v3.1) supported"
    ((PASS++))
  else
    echo "❌ FAIL: Mixed format not supported"
    ((FAIL++))
  fi
  
  rm -f "$test_ledger"
}

test_extension_fields_optional() {
  # Test that extension fields (ledger_id, parent_id, execution_duration_ms) are optional
  local test_ledger=$(mktemp)
  
  # Write v3.1 entry without extension fields
  echo '{"protocol":"AP/IO","version":"3.1","agent":"cls","ts":"2025-11-16T10:00:00+07:00","event":{"type":"task_start"}}' >> "$test_ledger"
  
  # Write v3.1 entry with extension fields
  echo '{"protocol":"AP/IO","version":"3.1","ledger_id":"ledger-20251116-021234-cls-001","parent_id":"parent-wo-wo-test","agent":"cls","ts":"2025-11-16T10:01:00+07:00","event":{"type":"task_result"},"data":{"execution_duration_ms":1250}}' >> "$test_ledger"
  
  # Read both
  local results=$("$READER" "$test_ledger" 2>/dev/null | wc -l)
  
  if [ "$results" -ge 2 ]; then
    echo "✅ PASS: Extension fields are optional (backward compatible)"
    ((PASS++))
  else
    echo "❌ FAIL: Extension fields not optional"
    ((FAIL++))
  fi
  
  rm -f "$test_ledger"
}

main() {
  echo "=========================================="
  echo "AP/IO v3.1 Backward Compatibility Tests"
  echo "=========================================="
  echo
  
  test_v10_format
  test_v31_format
  test_mixed_format
  test_extension_fields_optional
  
  echo
  echo "=========================================="
  echo "Summary: $PASS passed, $FAIL failed"
  echo "=========================================="
  
  [ "$FAIL" -eq 0 ] && exit 0 || exit 1
}

main "$@"
