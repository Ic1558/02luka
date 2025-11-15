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
    "timestamp": "2025-11-16T10:00:00+07:00",
    "event": {"type": "task_start"},
    "routing": {"targets": ["cls"], "broadcast": false, "priority": "normal"}
  }'
  
  local tmp=$(mktemp)
  echo "$event" > "$tmp"
  
  if "$ROUTER" "$tmp" >/dev/null 2>&1; then
    echo "✅ PASS: Single target routing works"
    ((PASS++))
  else
    echo "❌ FAIL: Single target routing failed"
    ((FAIL++))
  fi
  
  rm -f "$tmp"
}

test_multiple_targets() {
  local event='{
    "protocol": "AP/IO",
    "version": "3.1",
    "agent": "cls",
    "timestamp": "2025-11-16T10:00:00+07:00",
    "event": {"type": "task_start"},
    "routing": {"targets": ["cls", "andy"], "broadcast": false, "priority": "normal"}
  }'
  
  local tmp=$(mktemp)
  echo "$event" > "$tmp"
  
  if "$ROUTER" "$tmp" >/dev/null 2>&1; then
    echo "✅ PASS: Multiple targets routing works"
    ((PASS++))
  else
    echo "❌ FAIL: Multiple targets routing failed"
    ((FAIL++))
  fi
  
  rm -f "$tmp"
}

test_broadcast() {
  local event='{
    "protocol": "AP/IO",
    "version": "3.1",
    "agent": "cls",
    "timestamp": "2025-11-16T10:00:00+07:00",
    "event": {"type": "task_start"},
    "routing": {"targets": [], "broadcast": true, "priority": "normal"}
  }'
  
  local tmp=$(mktemp)
  echo "$event" > "$tmp"
  
  if "$ROUTER" "$tmp" >/dev/null 2>&1; then
    echo "✅ PASS: Broadcast routing works"
    ((PASS++))
  else
    echo "❌ FAIL: Broadcast routing failed"
    ((FAIL++))
  fi
  
  rm -f "$tmp"
}

test_priority_override() {
  local event='{
    "protocol": "AP/IO",
    "version": "3.1",
    "agent": "cls",
    "timestamp": "2025-11-16T10:00:00+07:00",
    "event": {"type": "task_start"},
    "routing": {"targets": ["cls"], "broadcast": false, "priority": "normal"}
  }'
  
  local tmp=$(mktemp)
  echo "$event" > "$tmp"
  
  if "$ROUTER" "$tmp" --priority high >/dev/null 2>&1; then
    echo "✅ PASS: Priority override works"
    ((PASS++))
  else
    echo "❌ FAIL: Priority override failed"
    ((FAIL++))
  fi
  
  rm -f "$tmp"
}

main() {
  echo "=========================================="
  echo "AP/IO v3.1 Routing Tests"
  echo "=========================================="
  echo
  
  test_single_target
  test_multiple_targets
  test_broadcast
  test_priority_override
  
  echo
  echo "=========================================="
  echo "Summary: $PASS passed, $FAIL failed"
  echo "=========================================="
  
  [ "$FAIL" -eq 0 ] && exit 0 || exit 1
}

main "$@"
