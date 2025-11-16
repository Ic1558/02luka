#!/usr/bin/env zsh
# Test Agent Ledger Writes
# Tests ledger writes for all agents (CLS, Andy, Hybrid)

set -euo pipefail

REPO_ROOT="${LUKA_SOT:-$HOME/02luka}"
LEDGER_HOOK_CLS="$REPO_ROOT/tools/cls_ledger_hook.zsh"
LEDGER_HOOK_ANDY="$REPO_ROOT/tools/andy_ledger_hook.zsh"
LEDGER_HOOK_HYBRID="$REPO_ROOT/tools/hybrid_ledger_hook.zsh"

echo "🧪 Testing Agent Ledger Writes"
echo "================================"
echo ""

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

test_ledger_write() {
  local agent="$1"
  local hook="$2"
  local event_type="$3"
  local task_id="$4"
  local summary="$5"
  
  echo "Testing $agent: $event_type ($task_id)"
  
  if [[ ! -x "$hook" ]]; then
    echo "  ❌ Hook not executable: $hook"
    ((TESTS_FAILED++))
    return 1
  fi
  
  # Run hook
  if "$hook" "$event_type" "$task_id" "$summary" '{"test":true}' >/dev/null 2>&1; then
    echo "  ✅ Hook executed successfully"
    
    # Verify ledger entry exists
    local date=$(date '+%Y-%m-%d')
    local ledger_file="$REPO_ROOT/g/ledger/$agent/$date.jsonl"
    
    if [[ -f "$ledger_file" ]]; then
      if grep -q "\"task_id\":\"$task_id\"" "$ledger_file" 2>/dev/null; then
        echo "  ✅ Ledger entry found in $ledger_file"
        ((TESTS_PASSED++))
        return 0
      else
        echo "  ⚠️  Ledger file exists but entry not found"
      fi
    else
      echo "  ⚠️  Ledger file not created: $ledger_file"
    fi
  else
    echo "  ❌ Hook execution failed"
    ((TESTS_FAILED++))
    return 1
  fi
  
  ((TESTS_FAILED++))
  return 1
}

test_status_update() {
  local agent="$1"
  local status_file="$REPO_ROOT/agents/$agent/status.json"
  
  echo "Testing $agent: Status update"
  
  if [[ -f "$status_file" ]]; then
    if python3 -m json.tool "$status_file" >/dev/null 2>&1; then
      echo "  ✅ Status file is valid JSON"
      
      local state=$(jq -r '.state' "$status_file" 2>/dev/null || echo "")
      if [[ -n "$state" ]]; then
        echo "  ✅ Status file has state: $state"
        ((TESTS_PASSED++))
        return 0
      else
        echo "  ⚠️  Status file missing state field"
      fi
    else
      echo "  ❌ Status file is invalid JSON"
      ((TESTS_FAILED++))
      return 1
    fi
  else
    echo "  ⚠️  Status file not found: $status_file"
    ((TESTS_FAILED++))
    return 1
  fi
}

# Test CLS
echo "📋 Testing CLS Agent"
echo "-------------------"
test_ledger_write "cls" "$LEDGER_HOOK_CLS" "task_start" "test-cls-001" "CLS test task start"
test_ledger_write "cls" "$LEDGER_HOOK_CLS" "task_result" "test-cls-001" "CLS test task result"
test_ledger_write "cls" "$LEDGER_HOOK_CLS" "heartbeat" "system" "CLS heartbeat"
test_status_update "cls"
echo ""

# Test Andy
echo "📋 Testing Andy Agent"
echo "-------------------"
test_ledger_write "andy" "$LEDGER_HOOK_ANDY" "task_start" "test-andy-001" "Andy test task start"
test_ledger_write "andy" "$LEDGER_HOOK_ANDY" "task_result" "test-andy-001" "Andy test task result"
test_ledger_write "andy" "$LEDGER_HOOK_ANDY" "info" "test-andy-002" "Andy info event"
test_status_update "andy"
echo ""

# Test Hybrid
echo "📋 Testing Hybrid Agent"
echo "-------------------"
test_ledger_write "hybrid" "$LEDGER_HOOK_HYBRID" "task_start" "test-hybrid-001" "Hybrid test task start"
test_ledger_write "hybrid" "$LEDGER_HOOK_HYBRID" "task_result" "test-hybrid-001" "Hybrid test task result"
test_ledger_write "hybrid" "$LEDGER_HOOK_HYBRID" "info" "test-hybrid-002" "Hybrid info event"
test_status_update "hybrid"
echo ""

# Summary
echo "================================"
echo "Test Summary"
echo "================================"
echo "✅ Tests Passed: $TESTS_PASSED"
echo "❌ Tests Failed: $TESTS_FAILED"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
  echo "🎉 All tests passed!"
  exit 0
else
  echo "⚠️  Some tests failed. Review output above."
  exit 1
fi
