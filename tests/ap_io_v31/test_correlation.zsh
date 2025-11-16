#!/usr/bin/env zsh
# AP/IO v3.1 Correlation Tests
# Purpose: Test event correlation functionality

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# tests/ap_io_v31 -> tests -> repo root
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WRITER="$REPO_ROOT/tools/ap_io_v31/writer.zsh"
READER="$REPO_ROOT/tools/ap_io_v31/reader.zsh"
CORR_ID_GEN="$REPO_ROOT/tools/ap_io_v31/correlation_id.zsh"

PASS=0
FAIL=0

test_correlation_id_generation() {
  local id1=$("$CORR_ID_GEN" 2>/dev/null)
  local id2=$("$CORR_ID_GEN" 2>/dev/null)
  
  if [ -n "$id1" ] && [ -n "$id2" ] && [ "$id1" != "$id2" ]; then
    echo "✅ PASS: Correlation ID generation works (unique)"
    ((PASS++))
  else
    echo "❌ FAIL: Correlation ID generation failed"
    ((FAIL++))
  fi
}

test_correlation_id_format() {
  local id=$("$CORR_ID_GEN" 2>/dev/null)
  
  if echo "$id" | grep -qE '^corr-[0-9]{8}-[0-9]{3}$'; then
    echo "✅ PASS: Correlation ID format correct"
    ((PASS++))
  else
    echo "❌ FAIL: Correlation ID format incorrect: $id"
    ((FAIL++))
  fi
}

test_correlation_query() {
  # Create test ledger with correlated events
  local test_ledger=$(mktemp)
  local corr_id="corr-$(date +%Y%m%d)-999"
  
  # Write correlated events
  echo "{\"protocol\":\"AP/IO\",\"version\":\"3.1\",\"agent\":\"cls\",\"ts\":\"2025-11-16T10:00:00+07:00\",\"correlation_id\":\"$corr_id\",\"event\":{\"type\":\"task_start\"}}" >> "$test_ledger"
  echo "{\"protocol\":\"AP/IO\",\"version\":\"3.1\",\"agent\":\"cls\",\"ts\":\"2025-11-16T10:01:00+07:00\",\"correlation_id\":\"$corr_id\",\"event\":{\"type\":\"task_result\"}}" >> "$test_ledger"
  
  # Query correlation
  local results=$("$READER" "$test_ledger" --correlation "$corr_id" 2>/dev/null | wc -l)
  
  if [ "$results" -ge 2 ]; then
    echo "✅ PASS: Correlation query works"
    ((PASS++))
  else
    echo "❌ FAIL: Correlation query failed (found $results, expected 2+)"
    ((FAIL++))
  fi
  
  rm -f "$test_ledger"
}

test_parent_id_correlation() {
  # Create test ledger with parent_id relationships
  local test_ledger=$(mktemp)
  local parent_id="parent-wo-wo-test-001"
  
  # Write events with same parent_id
  echo "{\"protocol\":\"AP/IO\",\"version\":\"3.1\",\"agent\":\"cls\",\"ts\":\"2025-11-16T10:00:00+07:00\",\"parent_id\":\"$parent_id\",\"event\":{\"type\":\"task_start\"}}" >> "$test_ledger"
  echo "{\"protocol\":\"AP/IO\",\"version\":\"3.1\",\"agent\":\"cls\",\"ts\":\"2025-11-16T10:01:00+07:00\",\"parent_id\":\"$parent_id\",\"event\":{\"type\":\"task_result\"}}" >> "$test_ledger"
  
  # Query by parent_id
  local results=$("$READER" "$test_ledger" --parent "$parent_id" 2>/dev/null | wc -l)
  
  if [ "$results" -ge 2 ]; then
    echo "✅ PASS: Parent ID correlation query works"
    ((PASS++))
  else
    echo "❌ FAIL: Parent ID correlation query failed (found $results, expected 2+)"
    ((FAIL++))
  fi
  
  rm -f "$test_ledger"
}

main() {
  echo "=========================================="
  echo "AP/IO v3.1 Correlation Tests"
  echo "=========================================="
  echo
  
  test_correlation_id_generation
  test_correlation_id_format
  test_correlation_query
  test_parent_id_correlation
  
  echo
  echo "=========================================="
  echo "Summary: $PASS passed, $FAIL failed"
  echo "=========================================="
  
  [ "$FAIL" -eq 0 ] && exit 0 || exit 1
}

main "$@"
