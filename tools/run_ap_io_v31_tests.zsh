#!/usr/bin/env zsh
# Run All AP/IO v3.1 Tests
# Purpose: Execute all test suites and report results

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

TEST_DIR="tests/ap_io_v31"
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
FAILED_LIST=()

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     AP/IO v3.1 Test Suite Runner                             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Check for required tools
MISSING_TOOLS=()
for tool in validator.zsh correlation_id.zsh router.zsh; do
  if [ ! -f "tools/ap_io_v31/$tool" ]; then
    MISSING_TOOLS+=("$tool")
  fi
done

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
  echo "⚠️  Warning: Missing optional tools:"
  for tool in "${MISSING_TOOLS[@]}"; do
    echo "    - tools/ap_io_v31/$tool"
  done
  echo ""
  echo "Some tests may fail if they depend on these tools."
  echo ""
fi

# Ensure ledger directory exists (for tests that don't use isolation)
mkdir -p g/ledger/cls
mkdir -p g/ledger/andy
mkdir -p g/ledger/hybrid

# Run each test file
for test_file in "$TEST_DIR"/*.zsh; do
  if [[ ! -f "$test_file" ]]; then
    continue
  fi
  
  test_name=$(basename "$test_file")
  ((TOTAL_TESTS++))
  
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Running: $test_name"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  if zsh "$test_file" 2>&1; then
    echo ""
    echo "✅ PASSED: $test_name"
    ((PASSED_TESTS++))
  else
    exit_code=$?
    echo ""
    echo "❌ FAILED: $test_name (exit code: $exit_code)"
    FAILED_LIST+=("$test_name")
    ((FAILED_TESTS++))
  fi
  
  echo ""
done

# Summary
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     Test Summary                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Total Test Suites: $TOTAL_TESTS"
echo "Passed: $PASSED_TESTS"
echo "Failed: $FAILED_TESTS"
echo ""

if [[ ${#FAILED_LIST[@]} -gt 0 ]]; then
  echo "Failed Tests:"
  for failed in "${FAILED_LIST[@]}"; do
    echo "  - $failed"
  done
  echo ""
fi

if [[ $FAILED_TESTS -eq 0 ]]; then
  echo "✅ All tests passed!"
  exit 0
else
  echo "❌ Some tests failed"
  exit 1
fi
