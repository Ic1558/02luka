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
  cat > "$test_ledger" <<EOF
{
  "ts": "2025-11-16T10:00:00+07:00",
  "agent": "cls",
  "event": "task_start",
  "task_id": "wo-test",
  "data": {
    "status": "started",
    "duration_sec": 5
  }
}
EOF
  
  if "$READER" "$test_ledger" >/dev/null 2>&1; then
    echo "✅ PASS: v1.0 format supported"
    PASS=$((PASS + 1))
  else
    echo "❌ FAIL: v1.0 format not supported"
    FAIL=$((FAIL + 1))
  fi
  
  rm -f "$test_ledger"
}

main() {
  echo "=========================================="
  echo "AP/IO v3.1 Backward Compatibility Tests"
  echo "=========================================="
  echo
  
  test_v10_format
  
  echo
  echo "=========================================="
  echo "Summary: $PASS passed, $FAIL failed"
  echo "=========================================="
  
  [ "$FAIL" -eq 0 ] && exit 0 || exit 1
}

main "$@"
