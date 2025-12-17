#!/usr/bin/env zsh
# Install Gemini Context Sync LaunchAgent
# Purpose: Automatically update context/gemini/system_snapshot.md (1-2x daily)

set -euo pipefail

REPO="${LUKA_SOT:-$HOME/02luka}"
PLIST_SRC="$REPO/LaunchAgents/com.02luka.gemini-context-sync.plist"
PLIST_DEST="$HOME/Library/LaunchAgents/com.02luka.gemini-context-sync.plist"
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
if launchctl print "gui/$(id -u)/com.02luka.gemini-context-sync" >/dev/null 2>&1; then
  log "✅ Gemini Context Sync LaunchAgent installed and loaded"
  log "📊 Snapshot will update daily at 09:00 and 21:00"
  log "📝 Logs: $LOG_DIR/gemini_context_sync.{stdout,stderr}.log"
else
  log "⚠️  LaunchAgent may not be loaded correctly"
  exit 1
fi

# Trigger initial execution
log "🚀 Triggering initial snapshot update..."
zsh "$REPO/tools/gemini_context_sync.zsh" || log "⚠️  Initial update failed (non-fatal)"

log "✅ Installation complete"
