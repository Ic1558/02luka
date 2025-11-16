#!/usr/bin/env zsh
# AP/IO v3.1 Hybrid Integration Tests
# Purpose: Test Hybrid agent integration with test isolation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WRITER="$REPO_ROOT/tools/ap_io_v31/writer.zsh"
READER="$REPO_ROOT/tools/ap_io_v31/reader.zsh"
AGENT="hybrid"

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

# Test 1: Writer creates entry for hybrid
test_writer_hybrid() {
  local test_ledger_dir=$(mktemp -d)
  trap "rm -rf '$test_ledger_dir'" EXIT
  
  if LEDGER_BASE_DIR="$test_ledger_dir" CORRELATION_ID="" \
    "$WRITER" "$AGENT" task_start "wo-test" "gg_orchestrator" "Test" >/dev/null 2>&1; then
    local ledger_file="$test_ledger_dir/hybrid/$(date +%Y-%m-%d).jsonl"
    if [ -f "$ledger_file" ]; then
      test_pass "Writer creates entry for hybrid agent"
    else
      test_fail "Ledger file not created"
    fi
  else
    test_fail "Writer failed for hybrid agent"
  fi
}

# Test 2: Reader can read hybrid entries
test_reader_hybrid() {
  local test_ledger_dir=$(mktemp -d)
  trap "rm -rf '$test_ledger_dir'" EXIT
  
  LEDGER_BASE_DIR="$test_ledger_dir" CORRELATION_ID="" \
    "$WRITER" "$AGENT" task_start "wo-test" "gg_orchestrator" "Test" >/dev/null 2>&1
  
  local ledger_file="$test_ledger_dir/hybrid/$(date +%Y-%m-%d).jsonl"
  if [ -f "$ledger_file" ]; then
    if "$READER" "$ledger_file" --agent hybrid >/dev/null 2>&1; then
      test_pass "Reader can read hybrid entries"
    else
      test_fail "Reader failed to read hybrid entries"
    fi
  else
    test_fail "Ledger file not created"
  fi
}

# Test 3: Hybrid entry has correct agent field
test_hybrid_agent_field() {
  local test_ledger_dir=$(mktemp -d)
  trap "rm -rf '$test_ledger_dir'" EXIT
  
  LEDGER_BASE_DIR="$test_ledger_dir" CORRELATION_ID="" \
    "$WRITER" "$AGENT" task_start "wo-test" "gg_orchestrator" "Test" >/dev/null 2>&1
  
  local ledger_file="$test_ledger_dir/hybrid/$(date +%Y-%m-%d).jsonl"
  if [ -f "$ledger_file" ]; then
    local agent_field=$(jq -r '.agent' "$ledger_file" 2>/dev/null | head -1)
    if [ "$agent_field" = "hybrid" ]; then
      test_pass "Hybrid entry has correct agent field"
    else
      test_fail "Agent field mismatch: expected hybrid, got $agent_field"
    fi
  else
    test_fail "Ledger file not created"
  fi
}

# Test 4: Hybrid entry supports all event types
test_hybrid_event_types() {
  local test_ledger_dir=$(mktemp -d)
  trap "rm -rf '$test_ledger_dir'" EXIT
  
  for event_type in task_start task_result error info; do
    if LEDGER_BASE_DIR="$test_ledger_dir" CORRELATION_ID="" \
      "$WRITER" "$AGENT" "$event_type" "wo-test" "gg_orchestrator" "Test" >/dev/null 2>&1; then
      # Entry created successfully
      :
    else
      test_fail "Failed to create entry for event type: $event_type"
      return 1
    fi
  done
  
  test_pass "Hybrid entry supports all event types"
}

# Test 5: Hybrid integration script exists
test_hybrid_integration_script() {
  local integration="$REPO_ROOT/agents/hybrid/ap_io_v31_integration.zsh"
  if [ -f "$integration" ] && [ -x "$integration" ]; then
    test_pass "Hybrid integration script exists"
  else
    test_fail "Hybrid integration script not found"
  fi
}

# Run all tests
main() {
  echo "Running hybrid integration tests..."
  echo ""
  
  test_writer_hybrid
  test_reader_hybrid
  test_hybrid_agent_field
  test_hybrid_event_types
  test_hybrid_integration_script
  
  echo ""
  echo "Summary: $PASS passed, $FAIL failed"
  
  if [ $FAIL -eq 0 ]; then
    exit 0
  else
    exit 1
  fi
}

main

