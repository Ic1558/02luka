#!/usr/bin/env zsh
# Install MLS Cursor Watcher LaunchAgent
set -euo pipefail

REPO="${LUKA_SOT:-$HOME/02luka}"
PLIST_SRC="$REPO/LaunchAgents/com.02luka.mls.cursor.watcher.plist"
PLIST_DEST="$HOME/Library/LaunchAgents/com.02luka.mls.cursor.watcher.plist"

echo "📦 Installing MLS Cursor Watcher LaunchAgent..."

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
if launchctl list | grep -q "com.02luka.mls.cursor.watcher"; then
  echo "✅ LaunchAgent installed and loaded"
  echo "   Schedule: Every 5 minutes (300 seconds)"
  echo "   Logs: $REPO/logs/mls_cursor_watcher.{out,err}.log"
  echo ""
  echo "🧪 Test run:"
  "$REPO/tools/mls_cursor_watcher.zsh" --dry-run 2>&1 | tail -5
else
  echo "⚠️  LaunchAgent loaded but not visible in list"
fi
