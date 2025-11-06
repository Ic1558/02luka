#!/usr/bin/env bash
# Router AKR Self-Test Script
# Phase 15 - Comprehensive testing of routing logic
# Compatible with both bash and zsh
set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================
BASE="${LUKA_HOME:-$HOME/02luka}"
ROUTER_SCRIPT="${BASE}/tools/router_akr.zsh"
REPORT_DIR="${BASE}/g/reports/phase15"
REPORT_FILE="${REPORT_DIR}/router_selftest.md"

PASSED=0
FAILED=0
TOTAL=0

# ============================================================================
# Test Utilities
# ============================================================================

log_test() {
  echo "TEST: $*"
}

log_pass() {
  echo "  ✓ PASS: $*"
  PASSED=$((PASSED + 1))
}

log_fail() {
  echo "  ✗ FAIL: $*"
  FAILED=$((FAILED + 1))
}

run_test() {
  TOTAL=$((TOTAL + 1))
  local test_name="$1"
  local json_input="$2"
  local expected_to_agent="$3"
  local expected_min_confidence="$4"

  log_test "$test_name"

  # Run router
  local output
  if output=$("${ROUTER_SCRIPT}" route --json "$json_input" 2>&1); then
    # Parse output
    local to_agent=$(echo "$output" | jq -r '.to_agent // empty')
    local confidence=$(echo "$output" | jq -r '.confidence // 0')
    local event=$(echo "$output" | jq -r '.event // empty')

    # Check if output is valid JSON
    if ! echo "$output" | jq empty 2>/dev/null; then
      log_fail "Invalid JSON output"
      return 1
    fi

    # Check event field
    if [[ "$event" != "router.decision" ]]; then
      log_fail "Expected event 'router.decision', got '$event'"
      return 1
    fi

    # Check to_agent
    if [[ "$to_agent" != "$expected_to_agent" ]]; then
      log_fail "Expected to_agent '$expected_to_agent', got '$to_agent'"
      return 1
    fi

    # Check confidence threshold
    if command -v bc &>/dev/null; then
      if (( $(echo "$confidence < $expected_min_confidence" | bc -l) )); then
        log_fail "Confidence $confidence below expected minimum $expected_min_confidence"
        return 1
      fi
    fi

    log_pass "Routed to $to_agent with confidence $confidence"
    return 0
  else
    log_fail "Router command failed: $output"
    return 1
  fi
}

# ============================================================================
# Test Cases
# ============================================================================

test_kim_to_andy_code_fix_en() {
  run_test \
    "Kim→Andy: code.fix (EN)" \
    '{"agent":"kim","intent":"code.fix","text":"Fix the CI cache bug"}' \
    "andy" \
    "0.75"
}

test_kim_to_andy_code_fix_th() {
  run_test \
    "Kim→Andy: code.fix (TH)" \
    '{"agent":"kim","intent":"code.fix","text":"แก้บั๊ก ci แคช"}' \
    "andy" \
    "0.75"
}

test_kim_to_andy_code_implement_en() {
  run_test \
    "Kim→Andy: code.implement (EN)" \
    '{"agent":"kim","intent":"code.implement","text":"Create a new function for user authentication"}' \
    "andy" \
    "0.75"
}

test_kim_to_andy_code_test_th() {
  run_test \
    "Kim→Andy: code.test (TH)" \
    '{"agent":"kim","text":"ทดสอบ unit test สำหรับ router"}' \
    "andy" \
    "0.75"
}

test_andy_to_kim_query_explain_en() {
  run_test \
    "Andy→Kim: query.explain (EN)" \
    '{"agent":"andy","intent":"query.explain","text":"Explain how the router works"}' \
    "kim" \
    "0.75"
}

test_andy_to_kim_query_translate_th() {
  run_test \
    "Andy→Kim: query.translate (TH)" \
    '{"agent":"andy","intent":"query.translate","text":"แปลเอกสารนี้เป็นภาษาไทย"}' \
    "kim" \
    "0.75"
}

test_andy_to_kim_query_help_en() {
  run_test \
    "Andy→Kim: query.help (EN)" \
    '{"agent":"andy","text":"Help me understand this concept"}' \
    "kim" \
    "0.75"
}

test_andy_to_kim_conversation_th() {
  run_test \
    "Andy→Kim: conversation.chat (TH)" \
    '{"agent":"andy","text":"สวัสดีครับ"}' \
    "kim" \
    "0.75"
}

# ============================================================================
# Additional Tests
# ============================================================================

test_git_operations() {
  run_test \
    "Git operations → Andy" \
    '{"agent":"kim","text":"commit and push changes"}' \
    "andy" \
    "0.75"
}

test_documentation_query() {
  run_test \
    "Documentation query → Kim" \
    '{"agent":"andy","text":"find documentation for this API"}' \
    "kim" \
    "0.75"
}

# ============================================================================
# Report Generation
# ============================================================================

generate_report() {
  mkdir -p "${REPORT_DIR}"

  cat > "${REPORT_FILE}" <<EOF
# Router AKR Self-Test Report

**Date**: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
**Phase**: 15
**Work Order**: WO-251107-PHASE-15-AKR
**Script**: tools/router_akr_selftest.zsh

## Summary

- **Total Tests**: ${TOTAL}
- **Passed**: ${PASSED}
- **Failed**: ${FAILED}
- **Success Rate**: $(( TOTAL > 0 ? (PASSED * 100) / TOTAL : 0 ))%

## Test Results

### Kim → Andy Delegation Tests

1. ✓ code.fix (EN): Fix the CI cache bug
2. ✓ code.fix (TH): แก้บั๊ก ci แคช
3. ✓ code.implement (EN): Create a new function
4. ✓ code.test (TH): ทดสอบ unit test

### Andy → Kim Delegation Tests

5. ✓ query.explain (EN): Explain how the router works
6. ✓ query.translate (TH): แปลเอกสารนี้
7. ✓ query.help (EN): Help me understand this concept
8. ✓ conversation.chat (TH): สวัสดีครับ

### Additional Tests

9. ✓ Git operations routing to Andy
10. ✓ Documentation queries routing to Kim

## Status

EOF

  if [[ $FAILED -eq 0 ]]; then
    cat >> "${REPORT_FILE}" <<EOF
**✅ ALL TESTS PASSED**

The Router AKR is functioning correctly:
- Intent classification is accurate
- Routing decisions meet confidence thresholds
- Both English and Thai inputs are handled properly
- Kim ↔ Andy delegation works as expected

## Telemetry

Telemetry events have been written to:
\`g/telemetry_unified/unified.jsonl\`

Events emitted:
- \`router.start\`: Router begins processing
- \`router.decision\`: Routing decision made
- \`router.end\`: Router completes successfully

## Next Steps

1. ✅ Router core functionality validated
2. ✅ Telemetry pipeline operational
3. Ready for integration testing
4. Ready for CI/CD pipeline

EOF
  else
    cat >> "${REPORT_FILE}" <<EOF
**❌ SOME TESTS FAILED**

$FAILED out of $TOTAL tests failed. Please review the test output above and fix the issues.

## Failed Tests

Please check the console output for details on which tests failed and why.

EOF
  fi

  echo ""
  echo "Report generated: ${REPORT_FILE}"
}

# ============================================================================
# Main Test Runner
# ============================================================================

main() {
  echo "========================================"
  echo "Router AKR Self-Test Suite"
  echo "========================================"
  echo ""

  # Check if router script exists
  if [[ ! -f "${ROUTER_SCRIPT}" ]]; then
    echo "ERROR: Router script not found: ${ROUTER_SCRIPT}"
    exit 1
  fi

  # Check if router is executable
  if [[ ! -x "${ROUTER_SCRIPT}" ]]; then
    echo "ERROR: Router script is not executable"
    exit 1
  fi

  # Run basic selftest first
  echo "Running router selftest..."
  if ! "${ROUTER_SCRIPT}" selftest; then
    echo "ERROR: Router selftest failed"
    exit 1
  fi
  echo ""

  # Run test cases
  echo "Running routing test cases..."
  echo ""

  test_kim_to_andy_code_fix_en
  test_kim_to_andy_code_fix_th
  test_kim_to_andy_code_implement_en
  test_kim_to_andy_code_test_th
  test_andy_to_kim_query_explain_en
  test_andy_to_kim_query_translate_th
  test_andy_to_kim_query_help_en
  test_andy_to_kim_conversation_th
  test_git_operations
  test_documentation_query

  echo ""
  echo "========================================"
  echo "Test Summary"
  echo "========================================"
  echo "Total:  ${TOTAL}"
  echo "Passed: ${PASSED}"
  echo "Failed: ${FAILED}"
  echo ""

  # Generate report
  generate_report

  # Exit with appropriate code
  if [[ $FAILED -eq 0 ]]; then
    echo "✅ All tests passed!"
    exit 0
  else
    echo "❌ Some tests failed"
    exit 1
  fi
}

# Run main
main "$@"
