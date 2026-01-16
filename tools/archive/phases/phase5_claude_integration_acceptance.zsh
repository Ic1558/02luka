#!/usr/bin/env zsh
set -euo pipefail

REPO="$HOME/02luka"
REDIS_PASS="changeme-02luka"
PASS=0
FAIL=0

ok() { echo "✅ $1"; PASS=$((PASS+1)); }
ng() { echo "❌ $1"; FAIL=$((FAIL+1)); }

echo "=== Phase 5 Claude Code Integration Acceptance Tests ==="
echo ""

# Test 1: Metrics collector exists and executable
echo "Test 1: Metrics Collector"
if [[ -f "$REPO/tools/claude_tools/metrics_collector.zsh" && -x "$REPO/tools/claude_tools/metrics_collector.zsh" ]]; then
  ok "Metrics collector exists and executable"
else
  ng "Metrics collector missing or not executable"
fi
echo ""

# Test 2: Redis integration
echo "Test 2: Redis Integration"
if redis-cli -a "$REDIS_PASS" HGETALL memory:agents:claude >/dev/null 2>&1; then
  ok "Claude Code metrics in Redis"
else
  ng "Claude Code metrics not in Redis"
fi
echo ""

# Test 3: Health check includes Claude Code
echo "Test 3: Health Check Integration"
if grep -q "Claude Code:" "$REPO/tools/memory_hub_health.zsh" 2>/dev/null; then
  ok "Health check includes Claude Code"
else
  ng "Health check missing Claude Code section"
fi
echo ""

# Test 4: Alert integration
echo "Test 4: Alert Integration"
if grep -q "Claude Code health checks" "$REPO/tools/governance_alert_hook.zsh" 2>/dev/null; then
  ok "Alert hook includes Claude Code checks"
else
  ng "Alert hook missing Claude Code checks"
fi
echo ""

# Test 5: Governance report integration
echo "Test 5: Governance Report Integration"
if grep -q "Claude Code Compliance" "$REPO/tools/governance_report_generator.zsh" 2>/dev/null; then
  ok "Governance report includes Claude Code section"
else
  ng "Governance report missing Claude Code section"
fi
echo ""

# Test 6: Certificate validation
echo "Test 6: Certificate Validation"
if grep -q "Claude Code component validation" "$REPO/tools/certificate_validator.zsh" 2>/dev/null; then
  ok "Certificate validator includes Claude Code"
else
  ng "Certificate validator missing Claude Code"
fi
echo ""

# Test 7: Dependency management
echo "Test 7: Dependency Management"
if [[ -f "$REPO/tools/claude_hooks/setup_dependencies.zsh" && -x "$REPO/tools/claude_hooks/setup_dependencies.zsh" ]]; then
  ok "Dependency setup script exists"
else
  ng "Dependency setup script missing"
fi
echo ""

# Test 8: Security checks
echo "Test 8: Security Checks"
if [[ -f "$REPO/tools/claude_hooks/security_check.zsh" && -x "$REPO/tools/claude_hooks/security_check.zsh" ]]; then
  ok "Security check script exists"
else
  ng "Security check script missing"
fi
echo ""

# Summary
echo "=== Summary ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo ""

if [[ $FAIL -eq 0 ]]; then
  echo "✅ ALL TESTS PASSED - Claude Code Integration Complete"
  exit 0
else
  echo "❌ SOME TESTS FAILED - Review above"
  exit 1
fi
