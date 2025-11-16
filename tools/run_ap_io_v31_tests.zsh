#!/usr/bin/env zsh
# AP/IO v3.1 Test Runner
# Purpose: Run all AP/IO v3.1 test suites and report results

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_DIR="$REPO_ROOT/tests/ap_io_v31"

# Test files to run (in order)
TEST_FILES=(
  "test_protocol_validation.zsh"
  "test_routing.zsh"
  "test_correlation.zsh"
  "test_backward_compat.zsh"
  "cls_testcases.zsh"
)

PASS=0
FAIL=0
FAILED_TESTS=()

log_test() {
  local status=$1
  local msg=$2
  if [ "$status" = "PASS" ]; then
    echo "✅ PASS: $msg"
    ((PASS++))
  else
    echo "❌ FAIL: $msg"
    ((FAIL++))
    FAILED_TESTS+=("$msg")
  fi
}

# Check test directory exists
if [ ! -d "$TEST_DIR" ]; then
  echo "❌ Test directory not found: $TEST_DIR" >&2
  exit 1
fi

# Check for required tools
MISSING_TOOLS=()
for tool in validator.zsh correlation_id.zsh router.zsh; do
  if [ ! -f "$REPO_ROOT/tools/ap_io_v31/$tool" ]; then
    MISSING_TOOLS+=("$tool")
  fi
done

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
  echo "⚠️  Warning: Missing tool dependencies:" >&2
  for tool in "${MISSING_TOOLS[@]}"; do
    echo "   - tools/ap_io_v31/$tool" >&2
  done
  echo "" >&2
fi

echo "=========================================="
echo "AP/IO v3.1 Test Suite Runner"
echo "=========================================="
echo ""
echo "Test Directory: $TEST_DIR"
echo "Test Files: ${#TEST_FILES[@]}"
echo ""

# Run each test file
for test_file in "${TEST_FILES[@]}"; do
  test_path="$TEST_DIR/$test_file"
  
  if [ ! -f "$test_path" ]; then
    log_test "FAIL" "$test_file (file not found)"
    continue
  fi
  
  # Check syntax
  if ! zsh -n "$test_path" 2>/dev/null; then
    log_test "FAIL" "$test_file (syntax error)"
    continue
  fi
  
  # Make executable
  chmod +x "$test_path" 2>/dev/null || true
  
  # Run test
  echo "--- Running: $test_file ---"
  if "$test_path" 2>&1; then
    log_test "PASS" "$test_file"
  else
    log_test "FAIL" "$test_file"
  fi
  echo ""
done

# Summary
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo "Total:  $((PASS + FAIL))"
echo ""

if [ ${#FAILED_TESTS[@]} -gt 0 ]; then
  echo "Failed Tests:"
  for test in "${FAILED_TESTS[@]}"; do
    echo "  - $test"
  done
  echo ""
fi

# Exit with appropriate code
if [ "$FAIL" -eq 0 ]; then
  echo "✅ All tests passed!"
  exit 0
else
  echo "❌ Some tests failed"
  exit 1
fi
