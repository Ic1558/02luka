#!/usr/bin/env zsh
set -euo pipefail

# Phase 6.1 Acceptance Tests

REPO="$HOME/02luka"
PASS=0
FAIL=0

ok() { echo "✅ $1"; PASS=$((PASS+1)); }
ng() { echo "❌ $1"; FAIL=$((FAIL+1)); }

echo "=== Phase 6.1 Acceptance Tests ==="
echo ""

# Test 1: Adaptive collector exists
echo "Test 1: Adaptive Collector"
if [[ -f "$REPO/tools/adaptive_collector.zsh" && -x "$REPO/tools/adaptive_collector.zsh" ]]; then
  ok "Adaptive collector exists and executable"
else
  ng "Adaptive collector missing or not executable"
fi
echo ""

# Test 2: Insights generated
echo "Test 2: Insights Generation"
"$REPO/tools/adaptive_collector.zsh" >/dev/null 2>&1
TODAY=$(date +%Y%m%d)
if [[ -f "$REPO/mls/adaptive/insights_${TODAY}.json" ]]; then
  ok "Insights file generated"
  
  # Check for required fields
  if jq -e '.trends' "$REPO/mls/adaptive/insights_${TODAY}.json" >/dev/null 2>&1; then
    ok "Insights file has trends field"
  else
    ng "Insights file missing trends field"
  fi
  
  if jq -e '.recommendation_summary' "$REPO/mls/adaptive/insights_${TODAY}.json" >/dev/null 2>&1; then
    ok "Insights file has recommendation_summary field"
  else
    ng "Insights file missing recommendation_summary field"
  fi
else
  ng "Insights file not generated"
fi
echo ""

# Test 3: Daily digest integration
echo "Test 3: Daily Digest Integration"
if grep -q "Adaptive Insights" "$REPO/tools/memory_daily_digest.zsh" 2>/dev/null; then
  ok "Daily digest includes adaptive insights section"
else
  ng "Daily digest missing adaptive insights section"
fi
echo ""

# Test 4: HTML dashboard
echo "Test 4: HTML Dashboard"
if [[ -f "$REPO/g/reports/dashboard/index.html" ]]; then
  ok "HTML dashboard exists"
else
  ng "HTML dashboard missing"
fi
echo ""

# Test 5: LaunchAgent
echo "Test 5: LaunchAgent"
if [[ -f "$HOME/Library/LaunchAgents/com.02luka.adaptive.collector.daily.plist" ]]; then
  ok "LaunchAgent plist exists"
else
  ng "LaunchAgent plist missing"
fi
echo ""

# Summary
echo "=== Summary ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo ""

if [[ $FAIL -eq 0 ]]; then
  echo "✅ ALL TESTS PASSED - Phase 6.1 Complete"
  exit 0
else
  echo "❌ SOME TESTS FAILED - Review above"
  exit 1
fi
