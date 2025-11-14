#!/usr/bin/env zsh
# Smoke test for check_runner library
# Purpose: Verify check_runner works correctly
# Usage: tests/check_runner_smoke.zsh

set -euo pipefail

BASE="${LUKA_SOT:-$HOME/02luka}"
cd "$BASE"

# Load check runner library
source "$BASE/tools/lib/check_runner.zsh"

echo "=== Check Runner Smoke Test ==="
echo ""

# Test 1: Pass check
echo "Test 1: Pass check"
cr_run_check test_pass -- echo "This should pass"
[[ "${CR_STATUS[test_pass]}" == "pass" ]] || { echo "❌ Test 1 failed"; exit 1; }
echo "✅ Test 1 passed"
echo ""

# Test 2: Fail check
echo "Test 2: Fail check"
cr_run_check test_fail -- false
[[ "${CR_STATUS[test_fail]}" == "fail:1" ]] || { echo "❌ Test 2 failed"; exit 1; }
echo "✅ Test 2 passed"
echo ""

# Test 3: Command not found
echo "Test 3: Command not found"
cr_run_check test_notfound -- command_that_does_not_exist_xyz
[[ "${CR_STATUS[test_notfound]}" =~ ^fail: ]] || { echo "❌ Test 3 failed"; exit 1; }
echo "✅ Test 3 passed"
echo ""

# Test 4: Check with output
echo "Test 4: Check with output"
cr_run_check test_output -- bash -c "echo 'stdout message'; echo 'stderr message' >&2; exit 0"
[[ "${CR_STATUS[test_output]}" == "pass" ]] || { echo "❌ Test 4 failed"; exit 1; }
[[ -n "${CR_STDOUT[test_output]}" ]] || { echo "❌ Test 4: stdout not captured"; exit 1; }
[[ -n "${CR_STDERR[test_output]}" ]] || { echo "❌ Test 4: stderr not captured"; exit 1; }
echo "✅ Test 4 passed"
echo ""

# Force report generation (normally done by EXIT trap)
echo "Generating reports..."
cr_write_reports

# Verify reports exist
echo ""
echo "Verifying reports..."
MD_FILE=$(ls -t "$CR_OUTDIR/system_checks_"*.md 2>/dev/null | head -1)
JSON_FILE=$(ls -t "$CR_OUTDIR/system_checks_"*.json 2>/dev/null | head -1)

if [[ -z "$MD_FILE" ]] || [[ ! -f "$MD_FILE" ]]; then
  echo "❌ Markdown report not found"
  exit 1
fi

if [[ -z "$JSON_FILE" ]] || [[ ! -f "$JSON_FILE" ]]; then
  echo "❌ JSON report not found"
  exit 1
fi

# Validate JSON
if ! jq . "$JSON_FILE" >/dev/null 2>&1; then
  echo "❌ JSON report is invalid"
  exit 1
fi

echo "✅ Reports generated and valid:"
echo "  - Markdown: $MD_FILE"
echo "  - JSON: $JSON_FILE"
echo ""

# Verify report content
PASSES=$(jq -r '.passes' "$JSON_FILE")
FAILS=$(jq -r '.fails' "$JSON_FILE")

if [[ "$PASSES" -lt 2 ]] || [[ "$FAILS" -lt 2 ]]; then
  echo "❌ Report content incorrect (passes: $PASSES, fails: $FAILS)"
  exit 1
fi

echo "✅ Report content verified (passes: $PASSES, fails: $FAILS)"
echo ""
echo "=== All Smoke Tests Passed ==="
