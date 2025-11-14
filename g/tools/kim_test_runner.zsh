#!/usr/bin/env zsh
# Kim K2 Test Runner
# Runs all Kim K2 related tests
# This is a REAL tool that provides REAL value - validates the system works!

set -euo pipefail

REPO="$HOME/02luka"
LOG="$REPO/logs/kim_test_runner.log"

mkdir -p "$(dirname "$LOG")"

ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

echo "$(ts) Starting Kim K2 test suite..." | tee -a "$LOG"

# Check if pytest is available
if ! command -v pytest &>/dev/null; then
  echo "❌ pytest not found. Install with: pip install pytest" | tee -a "$LOG"
  exit 1
fi

# Test files to run
TEST_FILES=(
  "$REPO/tests/test_kim_profile_router.py"
  "$REPO/tests/test_profile_store_edge_cases.py"
  "$REPO/tests/integration/test_kim_k2_flow.py"
)

PASSED=0
FAILED=0
MISSING=0

for test_file in "${TEST_FILES[@]}"; do
  if [[ ! -f "$test_file" ]]; then
    echo "⚠️  Test file not found: $test_file" | tee -a "$LOG"
    (( MISSING++ ))
    continue
  fi

  echo "Running: $(basename "$test_file")..." | tee -a "$LOG"
  
  if pytest -v "$test_file" >> "$LOG" 2>&1; then
    echo "  ✅ $(basename "$test_file") passed" | tee -a "$LOG"
    (( PASSED++ ))
  else
    echo "  ❌ $(basename "$test_file") failed" | tee -a "$LOG"
    (( FAILED++ ))
  fi
done

echo "" | tee -a "$LOG"
echo "Test Summary:" | tee -a "$LOG"
echo "  ✅ Passed: $PASSED" | tee -a "$LOG"
echo "  ❌ Failed: $FAILED" | tee -a "$LOG"
echo "  ⚠️  Missing: $MISSING" | tee -a "$LOG"

if [[ $FAILED -gt 0 ]]; then
  echo "$(ts) Test suite completed with failures" | tee -a "$LOG"
  exit 1
elif [[ $MISSING -gt 0 ]]; then
  echo "$(ts) Test suite completed with missing files" | tee -a "$LOG"
  exit 2
else
  echo "$(ts) Test suite completed successfully" | tee -a "$LOG"
  echo ""
  echo "✅ All tests passed!"
  echo "   This tool validates the system works - REAL value!"
  exit 0
fi
