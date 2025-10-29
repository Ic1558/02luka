#!/usr/bin/env bash
set -euo pipefail

# Disable OPS-Atomic Monitor
# Unloads and removes the monitoring LaunchAgent

PLIST_DST="${HOME}/Library/LaunchAgents/com.02luka.ops_atomic_monitor.plist"
LABEL="com.02luka.ops_atomic_monitor"

echo "🛑 Disabling OPS-Atomic Monitor..."

# Check if loaded
if ! launchctl list | grep -q "$LABEL"; then
  echo "ℹ️  Monitor not currently loaded"

  # Check if plist file exists
  if [ -f "$PLIST_DST" ]; then
    echo "📦 Removing plist file..."
    rm "$PLIST_DST"
    echo "✅ Monitor disabled (plist removed)"
  else
    echo "✅ Monitor already disabled"
  fi

  exit 0
fi

# Unload LaunchAgent
echo "🔄 Unloading LaunchAgent..."
launchctl unload "$PLIST_DST"

# Remove plist file
if [ -f "$PLIST_DST" ]; then
  echo "📦 Removing plist file..."
  rm "$PLIST_DST"
fi

# Verify unloaded
echo "✅ Verifying..."
if launchctl list | grep -q "$LABEL"; then
  echo "⚠️  WARNING: LaunchAgent still appears in list"
  exit 1
else
  echo "✅ OPS-Atomic Monitor disabled successfully"
fi
