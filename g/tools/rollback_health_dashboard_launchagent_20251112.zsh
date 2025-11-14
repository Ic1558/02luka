#!/usr/bin/env zsh
# Rollback script for Health Dashboard LaunchAgent deployment
# Generated: 2025-11-12
# Feature: health-dashboard-auto-update

set -euo pipefail

REPO="${LUKA_SOT:-$HOME/02luka}"
PLIST_DEST="$HOME/Library/LaunchAgents/com.02luka.health.dashboard.plist"
BACKUP_DIR="${1:-backups/health_dashboard_launchagent_rollback}"

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" >&2
}

log "=== Rolling back Health Dashboard LaunchAgent ==="

# Step 1: Unload LaunchAgent if loaded
if launchctl list | grep -q "com.02luka.health.dashboard"; then
  log "🔄 Unloading LaunchAgent..."
  launchctl unload "$PLIST_DEST" 2>/dev/null || true
  log "✅ LaunchAgent unloaded"
else
  log "ℹ️  LaunchAgent not loaded"
fi

# Step 2: Remove plist file
if [[ -f "$PLIST_DEST" ]]; then
  log "🗑️  Removing plist file..."
  rm -f "$PLIST_DEST"
  log "✅ Plist removed"
else
  log "ℹ️  Plist file not found"
fi

# Step 3: Restore from backup if provided
if [[ -n "${1:-}" && -d "$BACKUP_DIR" && -f "$BACKUP_DIR/com.02luka.health.dashboard.plist" ]]; then
  log "📋 Restoring from backup: $BACKUP_DIR"
  cp "$BACKUP_DIR/com.02luka.health.dashboard.plist" "$PLIST_DEST"
  plutil -lint "$PLIST_DEST" || {
    log "❌ Backup plist validation failed"
    rm -f "$PLIST_DEST"
    exit 1
  }
  launchctl load "$PLIST_DEST" 2>/dev/null || log "⚠️  Failed to load backup plist"
  log "✅ Backup restored"
fi

log "✅ Rollback complete"
log "ℹ️  Manual dashboard execution still available: node ~/02luka/run/health_dashboard.cjs"

