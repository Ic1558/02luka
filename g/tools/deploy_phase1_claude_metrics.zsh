#!/usr/bin/env zsh
set -euo pipefail

REPO="$HOME/02luka"

echo "=== Phase 1: Redis + Metrics Integration ==="
echo ""

# Verify prerequisites
echo "Checking prerequisites..."
redis-cli -a changeme-02luka PING >/dev/null 2>&1 || { echo "❌ Redis not available"; exit 1; }
echo "✅ Redis available"

[[ -f "$REPO/tools/claude_tools/metrics_collector.zsh" ]] || { echo "❌ Metrics collector missing"; exit 1; }
echo "✅ Metrics collector exists"

# Test metrics collection
echo ""
echo "Testing metrics collection..."
"$REPO/tools/claude_tools/metrics_collector.zsh"

# Verify Redis data
echo ""
echo "Verifying Redis data..."
if redis-cli -a changeme-02luka HGETALL memory:agents:claude >/dev/null 2>&1; then
  echo "✅ Claude Code metrics in Redis"
  redis-cli -a changeme-02luka HGETALL memory:agents:claude | head -5
else
  echo "❌ No metrics in Redis"
  exit 1
fi

# Test monthly aggregation
echo ""
echo "Testing monthly aggregation..."
"$REPO/tools/memory_metrics_collector.zsh"

YEARMONTH=$(date +%Y%m)
if [[ -f "$REPO/g/reports/memory_metrics_${YEARMONTH}.json" ]]; then
  echo "✅ Monthly metrics generated"
  jq '.agents.claude // "not found"' "$REPO/g/reports/memory_metrics_${YEARMONTH}.json" | head -3
else
  echo "❌ Monthly metrics not generated"
  exit 1
fi

# Verify LaunchAgent
echo ""
echo "Verifying LaunchAgent..."
if launchctl list | grep -q com.02luka.claude.metrics.collector; then
  echo "✅ LaunchAgent loaded"
else
  echo "⚠️  LaunchAgent not loaded (will load now)"
  launchctl load ~/Library/LaunchAgents/com.02luka.claude.metrics.collector.plist 2>/dev/null || true
fi

echo ""
echo "✅ Phase 1 deployment complete"
