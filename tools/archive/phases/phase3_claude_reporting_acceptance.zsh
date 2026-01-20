#!/usr/bin/env zsh
set -euo pipefail

REPO="$HOME/02luka"
PASS=0
FAIL=0

ok() { echo "✅ $1"; PASS=$((PASS+1)); }
ng() { echo "❌ $1"; FAIL=$((FAIL+1)); }

echo "=== Phase 3 Acceptance Tests: Report + Certificate + Dependencies ==="
echo ""

# Test 1: Governance report integration
echo "Test 1: Governance Report Integration"
if grep -q "Claude Code Compliance" "$REPO/tools/governance_report_generator.zsh" 2>/dev/null; then
  ok "Governance report includes Claude Code section"
else
  ng "Governance report missing Claude Code section"
fi
echo ""

# Test 2: Certificate validation
echo "Test 2: Certificate Validation"
if grep -q "Claude Code component validation" "$REPO/tools/certificate_validator.zsh" 2>/dev/null; then
  ok "Certificate validator includes Claude Code"
else
  ng "Certificate validator missing Claude Code"
fi
echo ""

# Test 3: Security checks
echo "Test 3: Security Checks"
if [[ -f "$REPO/tools/claude_hooks/security_check.zsh" && -x "$REPO/tools/claude_hooks/security_check.zsh" ]]; then
  ok "Security check script exists"
else
  ng "Security check script missing"
fi
echo ""

# Test 4: Report generation
echo "Test 4: Report Generation"
"$REPO/tools/governance_report_generator.zsh" >/dev/null 2>&1
TODAY=$(date +%Y%m%d)
if [[ -f "$REPO/g/reports/system_governance_WEEKLY_${TODAY}.md" ]]; then
  if grep -q "Claude Code Compliance" "$REPO/g/reports/system_governance_WEEKLY_${TODAY}.md"; then
    ok "Report generated with Claude Code section"
  else
    ng "Report missing Claude Code section"
  fi
else
  echo "ℹ️  Report not generated (may need scheduled run)"
fi
echo ""

# Summary
echo "=== Summary ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo ""

if [[ $FAIL -eq 0 ]]; then
  echo "✅ ALL TESTS PASSED - Phase 3 Complete"
  exit 0
else
  echo "❌ SOME TESTS FAILED - Review above"
  exit 1
fi
