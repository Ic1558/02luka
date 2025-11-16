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
    PASS=$((PASS + 1))
  else
    echo "❌ FAIL: Correlation ID generation failed"
    FAIL=$((FAIL + 1))
  fi
}

test_correlation_id_format() {
  local id=$("$CORR_ID_GEN" 2>/dev/null)
  
  if echo "$id" | grep -qE '^corr-[0-9]{8}-[0-9]{3}$'; then
    echo "✅ PASS: Correlation ID format correct"
    PASS=$((PASS + 1))
  else
    echo "❌ FAIL: Correlation ID format incorrect: $id"
    FAIL=$((FAIL + 1))
  fi
}

main() {
  echo "=========================================="
  echo "AP/IO v3.1 Correlation Tests"
  echo "=========================================="
  echo
  
  test_correlation_id_generation
  test_correlation_id_format
  
  echo
  echo "=========================================="
  echo "Summary: $PASS passed, $FAIL failed"
  echo "=========================================="
  
  [ "$FAIL" -eq 0 ] && exit 0 || exit 1
}

main "$@"
