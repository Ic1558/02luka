#!/usr/bin/env zsh
set -euo pipefail

REPO="$HOME/02luka"
REDIS_PASS="changeme-02luka"
PASS=0
FAIL=0

ok() { echo "✅ $1"; PASS=$((PASS+1)); }
ng() { echo "❌ $1"; FAIL=$((FAIL+1)); }

echo "=== Phase 1 Acceptance Tests: Redis + Metrics Integration ==="
echo ""

# Test 1: Metrics collector exists
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

# Test 3: Monthly aggregation
echo "Test 3: Monthly Aggregation"
YEARMONTH=$(date +%Y%m)
if [[ -f "$REPO/g/reports/memory_metrics_${YEARMONTH}.json" ]]; then
  if jq -e '.agents.claude' "$REPO/g/reports/memory_metrics_${YEARMONTH}.json" >/dev/null 2>&1; then
    ok "Monthly metrics include Claude Code"
  else
    ng "Monthly metrics missing Claude Code"
  fi
else
  ng "Monthly metrics file not found"
fi
echo ""

# Test 4: LaunchAgent
echo "Test 4: LaunchAgent"
if launchctl list | grep -q com.02luka.claude.metrics.collector; then
  ok "LaunchAgent loaded"
else
  ng "LaunchAgent not loaded"
fi
echo ""

# Summary
echo "=== Summary ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo ""

if [[ $FAIL -eq 0 ]]; then
  echo "✅ ALL TESTS PASSED - Phase 1 Complete"
  exit 0
else
  echo "❌ SOME TESTS FAILED - Review above"
  exit 1
fi
