#!/usr/bin/env zsh
set -euo pipefail

REPO="$HOME/02luka"
PASS=0
FAIL=0

ok() { echo "✅ $1"; PASS=$((PASS+1)); }
ng() { echo "❌ $1"; FAIL=$((FAIL+1)); }

echo "=== Phase 2 Acceptance Tests: Health + Alert Integration ==="
echo ""

# Test 1: Health check integration
echo "Test 1: Health Check Integration"
if grep -q "Claude Code:" "$REPO/tools/memory_hub_health.zsh" 2>/dev/null; then
  ok "Health check includes Claude Code"
else
  ng "Health check missing Claude Code section"
fi
echo ""

# Test 2: Alert integration
echo "Test 2: Alert Integration"
if grep -q "Claude Code health checks" "$REPO/tools/governance_alert_hook.zsh" 2>/dev/null; then
  ok "Alert hook includes Claude Code checks"
else
  ng "Alert hook missing Claude Code checks"
fi
echo ""

# Test 3: Dependency management
echo "Test 3: Dependency Management"
if [[ -f "$REPO/tools/claude_hooks/setup_dependencies.zsh" && -x "$REPO/tools/claude_hooks/setup_dependencies.zsh" ]]; then
  ok "Dependency setup script exists"
else
  ng "Dependency setup script missing"
fi
echo ""

# Test 4: Unified health score
echo "Test 4: Unified Health Score"
health_output=$("$REPO/tools/memory_hub_health.zsh" 2>&1)
if echo "$health_output" | grep -q "Health Score:"; then
  ok "Health score calculated"
else
  ng "Health score not calculated"
fi
echo ""

# Summary
echo "=== Summary ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo ""

if [[ $FAIL -eq 0 ]]; then
  echo "✅ ALL TESTS PASSED - Phase 2 Complete"
  exit 0
else
  echo "❌ SOME TESTS FAILED - Review above"
  exit 1
fi
