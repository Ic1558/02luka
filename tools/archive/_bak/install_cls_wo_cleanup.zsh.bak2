#!/usr/bin/env zsh
# Install CLS Work Order Cleanup LaunchAgent
set -euo pipefail

REPO="${LUKA_SOT:-$HOME/02luka}"
PLIST_SRC="$REPO/LaunchAgents/com.02luka.cls.wo.cleanup.plist"
PLIST_DEST="$HOME/Library/LaunchAgents/com.02luka.cls.wo.cleanup.plist"

echo "📦 Installing CLS WO Cleanup LaunchAgent..."

# Copy plist
cp "$PLIST_SRC" "$PLIST_DEST"

# Validate
plutil -lint "$PLIST_DEST" || {
  echo "❌ Plist validation failed"
  exit 1
}

# Unload existing if present
launchctl unload "$PLIST_DEST" 2>/dev/null || true

# Load LaunchAgent
launchctl load "$PLIST_DEST"

# Verify
if launchctl list | grep -q "com.02luka.cls.wo.cleanup"; then
  echo "✅ LaunchAgent installed and loaded"
  echo "   Scheduled: Daily at 02:00"
  echo "   Logs: $REPO/logs/cls_wo_cleanup.{out,err}.log"
else
  echo "⚠️  LaunchAgent loaded but not visible in list"
fi
