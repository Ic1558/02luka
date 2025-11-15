#!/usr/bin/env zsh
# AP/IO v3.1 Routing Tests
# Purpose: Test event routing functionality

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# tests/ap_io_v31 -> tests -> repo root
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ROUTER="$REPO_ROOT/tools/ap_io_v31/router.zsh"

PASS=0
FAIL=0

test_single_target() {
  local event='{
    "protocol": "AP/IO",
    "version": "3.1",
    "agent": "cls",
    "ts": "2025-11-16T10:00:00+07:00",
    "event": {"type": "task_start", "task_id": "wo-test"}
  }'
  
  local tmp_event=$(mktemp)
  echo "$event" > "$tmp_event"
  
  if "$ROUTER" "$tmp_event" --targets cls >/dev/null 2>&1; then
    echo "✅ PASS: Single target routing works"
    PASS=$((PASS + 1))
  else
    echo "❌ FAIL: Single target routing failed"
    FAIL=$((FAIL + 1))
  fi
  
  rm -f "$tmp_event"
}

main() {
  echo "=========================================="
  echo "AP/IO v3.1 Routing Tests"
  echo "=========================================="
  echo
  
  test_single_target
  
  echo
  echo "=========================================="
  echo "Summary: $PASS passed, $FAIL failed"
  echo "=========================================="
  
  [ "$FAIL" -eq 0 ] && exit 0 || exit 1
}

main "$@"
