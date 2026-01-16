#!/usr/bin/env zsh
set -euo pipefail

REPO="$HOME/02luka"

echo "=== Phase 2: Health + Alert Integration ==="
echo ""

# Verify Phase 1
echo "Verifying Phase 1..."
if redis-cli -a changeme-02luka HGETALL memory:agents:claude >/dev/null 2>&1; then
  echo "✅ Phase 1 operational"
else
  echo "❌ Phase 1 not operational - run Phase 1 first"
  exit 1
fi

# Test health check
echo ""
echo "Testing health check integration..."
if grep -q "Claude Code:" "$REPO/tools/memory_hub_health.zsh" 2>/dev/null; then
  echo "✅ Health check includes Claude Code"
  "$REPO/tools/memory_hub_health.zsh" 2>&1 | grep -A 10 "Claude Code:" || true
else
  echo "❌ Health check missing Claude Code section"
  exit 1
fi

# Test dependency management
echo ""
echo "Testing dependency management..."
"$REPO/tools/claude_hooks/setup_dependencies.zsh" 2>&1 | tail -5

# Test alert hook (dry run)
echo ""
echo "Testing alert hook..."
if grep -q "Claude Code health checks" "$REPO/tools/governance_alert_hook.zsh" 2>/dev/null; then
  echo "✅ Alert hook includes Claude Code checks"
else
  echo "❌ Alert hook missing Claude Code checks"
  exit 1
fi

# Verify LaunchAgent
echo ""
echo "Verifying LaunchAgent..."
if [[ -f ~/Library/LaunchAgents/com.02luka.governance.alerts.plist ]]; then
  if launchctl list | grep -q com.02luka.governance.alerts; then
    echo "✅ Alert LaunchAgent loaded"
  else
    echo "⚠️  Alert LaunchAgent not loaded (will load now)"
    launchctl load ~/Library/LaunchAgents/com.02luka.governance.alerts.plist 2>/dev/null || true
  fi
else
  echo "ℹ️  Alert LaunchAgent plist not found (will be created in Phase 5 full deployment)"
fi

echo ""
echo "✅ Phase 2 deployment complete"
