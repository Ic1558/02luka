#!/usr/bin/env bash
set -euo pipefail

# Enable OPS-Atomic Monitor
# Deploys and loads the 5-minute heartbeat monitoring LaunchAgent

REPO_ROOT="/Users/icmini/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka/02luka-repo"
PLIST_SRC="${REPO_ROOT}/LaunchAgents/com.02luka.ops_atomic_monitor.plist"
PLIST_DST="${HOME}/Library/LaunchAgents/com.02luka.ops_atomic_monitor.plist"
LABEL="com.02luka.ops_atomic_monitor"

echo "🔧 Enabling OPS-Atomic Monitor..."

# Validate source plist exists
if [ ! -f "$PLIST_SRC" ]; then
  echo "❌ ERROR: Source plist not found: $PLIST_SRC"
  exit 1
fi

# Validate plist syntax
echo "📋 Validating plist syntax..."
if ! plutil -lint "$PLIST_SRC" >/dev/null 2>&1; then
  echo "❌ ERROR: Invalid plist syntax"
  exit 1
fi

# Unload if already loaded
echo "🛑 Unloading existing instance (if any)..."
launchctl unload "$PLIST_DST" 2>/dev/null || true

# Copy plist to LaunchAgents directory
echo "📦 Deploying LaunchAgent..."
cp "$PLIST_SRC" "$PLIST_DST"
chmod 644 "$PLIST_DST"

# Load LaunchAgent
echo "▶️  Loading LaunchAgent..."
launchctl load "$PLIST_DST"

# Verify loaded
echo "✅ Verifying..."
if launchctl list | grep -q "$LABEL"; then
  echo "✅ OPS-Atomic Monitor enabled and running"
  echo ""
  echo "📊 Status:"
  launchctl list | grep "$LABEL"
  echo ""
  echo "📝 Logs:"
  echo "   - Monitor: ${REPO_ROOT}/g/logs/ops_monitor.log"
  echo "   - Errors:  ${REPO_ROOT}/g/logs/ops_monitor.err"
  echo ""
  echo "🔄 Schedule: Every 5 minutes"
else
  echo "⚠️  WARNING: LaunchAgent loaded but not visible in list"
  exit 1
fi
