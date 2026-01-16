#!/usr/bin/env zsh
# Install Health Dashboard LaunchAgent
# Purpose: Automatically update health_dashboard.json every 30 minutes

set -euo pipefail

REPO="${LUKA_SOT:-$HOME/02luka}"
PLIST_SRC="$REPO/LaunchAgents/com.02luka.health.dashboard.plist"
PLIST_DEST="$HOME/Library/LaunchAgents/com.02luka.health.dashboard.plist"
LOG_DIR="$REPO/logs"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" >&2
}

# Check if source plist exists
if [[ ! -f "$PLIST_SRC" ]]; then
  log "❌ Source plist not found: $PLIST_SRC"
  exit 1
fi

# Copy plist to LaunchAgents directory
log "📋 Copying plist to LaunchAgents..."
cp "$PLIST_SRC" "$PLIST_DEST"

# Validate plist syntax
log "✅ Validating plist syntax..."
if ! plutil -lint "$PLIST_DEST" >/dev/null 2>&1; then
  log "❌ Plist validation failed"
  rm -f "$PLIST_DEST"
  exit 1
fi

# Unload existing LaunchAgent if present
log "🔄 Unloading existing LaunchAgent (if any)..."
launchctl unload "$PLIST_DEST" 2>/dev/null || true

# Load LaunchAgent
log "⬆️  Loading LaunchAgent..."
if ! launchctl load "$PLIST_DEST" 2>/dev/null; then
  log "❌ Failed to load LaunchAgent"
  exit 1
fi

# Verify LaunchAgent is loaded
log "🔍 Verifying LaunchAgent status..."
if launchctl list | grep -q "com.02luka.health.dashboard"; then
  log "✅ Health Dashboard LaunchAgent installed and loaded"
  log "📊 Dashboard will update every 30 minutes"
  log "📝 Logs: $LOG_DIR/health_dashboard.{out,err}.log"
else
  log "⚠️  LaunchAgent may not be loaded correctly"
  exit 1
fi

# Trigger initial execution
log "🚀 Triggering initial dashboard update..."
launchctl kickstart gui/$(id -u)/com.02luka.health.dashboard 2>/dev/null || true

log "✅ Installation complete"

