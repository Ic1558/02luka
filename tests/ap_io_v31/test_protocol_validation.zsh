#!/usr/bin/env zsh
# AP/IO v3.1 Protocol Validation Tests
# Purpose: Test protocol message validation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# tests/ap_io_v31 -> tests -> repo root
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VALIDATOR="$REPO_ROOT/tools/ap_io_v31/validator.zsh"

PASS=0
FAIL=0

test_valid_message() {
  # Test with "ts" (schema format)
  local msg='{
    "protocol": "AP/IO",
    "version": "3.1",
    "agent": "cls",
    "ts": "2025-11-16T10:00:00+07:00",
    "event": {"type": "task_start", "task_id": "wo-test", "source": "gg_orchestrator", "summary": "Test"}
  }'
  
  local result=0
  echo "$msg" | "$VALIDATOR" - >/dev/null 2>&1 || result=$?
  if [ "$result" -eq 0 ]; then
    echo "✅ PASS: Valid message accepted (ts format)"
    PASS=$((PASS + 1))
  else
    echo "❌ FAIL: Valid message rejected (ts format)"
    FAIL=$((FAIL + 1))
  fi
  
  # Test with "timestamp" (alternative format)
  local msg2='{
    "protocol": "AP/IO",
    "version": "3.1",
    "agent": "cls",
    "timestamp": "2025-11-16T10:00:00+07:00",
    "event": {"type": "task_start", "task_id": "wo-test", "source": "gg_orchestrator", "summary": "Test"}
  }'
  
  result=0
  echo "$msg2" | "$VALIDATOR" - >/dev/null 2>&1 || result=$?
  if [ "$result" -eq 0 ]; then
    echo "✅ PASS: Valid message accepted (timestamp format)"
    PASS=$((PASS + 1))
  else
    echo "❌ FAIL: Valid message rejected (timestamp format)"
    FAIL=$((FAIL + 1))
  fi
}

test_invalid_protocol() {
  local msg='{
    "protocol": "INVALID",
    "version": "3.1",
    "agent": "cls",
    "timestamp": "2025-11-16T10:00:00+07:00",
    "event": {"type": "task_start"}
  }'
  
  if ! echo "$msg" | "$VALIDATOR" - >/dev/null 2>&1; then
    echo "✅ PASS: Invalid protocol rejected"
    ((PASS++))
  else
    echo "❌ FAIL: Invalid protocol accepted"
    ((FAIL++))
  fi
}

test_invalid_version() {
  local msg='{
    "protocol": "AP/IO",
    "version": "2.0",
    "agent": "cls",
    "timestamp": "2025-11-16T10:00:00+07:00",
    "event": {"type": "task_start"}
  }'
  
  if ! echo "$msg" | "$VALIDATOR" - >/dev/null 2>&1; then
    echo "✅ PASS: Invalid version rejected"
    ((PASS++))
  else
    echo "❌ FAIL: Invalid version accepted"
    ((FAIL++))
  fi
}

test_invalid_agent() {
  local msg='{
    "protocol": "AP/IO",
    "version": "3.1",
    "agent": "invalid_agent",
    "timestamp": "2025-11-16T10:00:00+07:00",
    "event": {"type": "task_start"}
  }'
  
  if ! echo "$msg" | "$VALIDATOR" - >/dev/null 2>&1; then
    echo "✅ PASS: Invalid agent rejected"
    ((PASS++))
  else
    echo "❌ FAIL: Invalid agent accepted"
    ((FAIL++))
  fi
}

test_missing_required_field() {
  local msg='{
    "protocol": "AP/IO",
    "version": "3.1",
    "agent": "cls"
  }'
  
  if ! echo "$msg" | "$VALIDATOR" - >/dev/null 2>&1; then
    echo "✅ PASS: Missing required field rejected"
    ((PASS++))
  else
    echo "❌ FAIL: Missing required field accepted"
    ((FAIL++))
  fi
}

test_ledger_id_format() {
  local msg='{
    "protocol": "AP/IO",
    "version": "3.1",
    "ledger_id": "ledger-20251116-021234-cls-001",
    "agent": "cls",
    "ts": "2025-11-16T10:00:00+07:00",
    "event": {"type": "task_start"}
  }'
  
  if echo "$msg" | "$VALIDATOR" - >/dev/null 2>&1; then
    echo "✅ PASS: Valid ledger_id format accepted"
    ((PASS++))
  else
    echo "❌ FAIL: Valid ledger_id format rejected"
    ((FAIL++))
  fi
}

test_invalid_ledger_id_format() {
  local msg='{
    "protocol": "AP/IO",
    "version": "3.1",
    "ledger_id": "invalid-format",
    "agent": "cls",
    "ts": "2025-11-16T10:00:00+07:00",
    "event": {"type": "task_start"}
  }'
  
  if ! echo "$msg" | "$VALIDATOR" - >/dev/null 2>&1; then
    echo "✅ PASS: Invalid ledger_id format rejected"
    ((PASS++))
  else
    echo "❌ FAIL: Invalid ledger_id format accepted"
    ((FAIL++))
  fi
}

test_parent_id_format() {
  local msg='{
    "protocol": "AP/IO",
    "version": "3.1",
    "parent_id": "parent-wo-wo-test-001",
    "agent": "cls",
    "ts": "2025-11-16T10:00:00+07:00",
    "event": {"type": "task_start"}
  }'
  
  if echo "$msg" | "$VALIDATOR" - >/dev/null 2>&1; then
    echo "✅ PASS: Valid parent_id format accepted"
    ((PASS++))
  else
    echo "❌ FAIL: Valid parent_id format rejected"
    ((FAIL++))
  fi
}

test_execution_duration_ms() {
  local msg='{
    "protocol": "AP/IO",
    "version": "3.1",
    "agent": "cls",
    "ts": "2025-11-16T10:00:00+07:00",
    "event": {"type": "task_result"},
    "data": {
      "execution_duration_ms": 1250
    }
  }'
  
  if echo "$msg" | "$VALIDATOR" - >/dev/null 2>&1; then
    echo "✅ PASS: execution_duration_ms field accepted"
    ((PASS++))
  else
    echo "❌ FAIL: execution_duration_ms field rejected"
    ((FAIL++))
  fi
}

main() {
  echo "=========================================="
  echo "AP/IO v3.1 Protocol Validation Tests"
  echo "=========================================="
  echo
  
  test_valid_message
  test_invalid_protocol
  test_invalid_version
  test_invalid_agent
  test_missing_required_field
  test_ledger_id_format
  test_invalid_ledger_id_format
  test_parent_id_format
  test_execution_duration_ms
  
  echo
  echo "=========================================="
  echo "Summary: $PASS passed, $FAIL failed"
  echo "=========================================="
  
  [ "$FAIL" -eq 0 ] && exit 0 || exit 1
}

main "$@"
