#!/usr/bin/env zsh
# Rollback script for Mary Phase 2.1 (Alerts + Metrics)
# Generated: 2025-11-12T04:10:00Z
set -euo pipefail

BASE="$HOME/02luka"
BACKUP_DIR="${1:-g/reports/deployments/mary_phase2_1_*}"

echo "== Rolling back Mary Phase 2.1 =="
echo ""

# Find latest backup
LATEST_BACKUP=$(ls -td $BASE/$BACKUP_DIR 2>/dev/null | head -1)
if [[ -z "$LATEST_BACKUP" ]]; then
  echo "❌ No backup found in $BACKUP_DIR"
  exit 1
fi

echo "Using backup: $LATEST_BACKUP"

# Stop LaunchAgents
echo "1. Stopping LaunchAgents..."
launchctl unload ~/Library/LaunchAgents/com.02luka.mary.metrics.daily.plist 2>/dev/null || true
launchctl unload ~/Library/LaunchAgents/com.02luka.mary.alerts.plist 2>/dev/null || true
sleep 1

# Restore scripts (if backups exist)
if [[ -f "$LATEST_BACKUP/mary_dispatcher_health_check.zsh.before" ]]; then
  echo "2. Restoring health check..."
  cp -f "$LATEST_BACKUP/mary_dispatcher_health_check.zsh.before" "$BASE/tools/mary_dispatcher_health_check.zsh"
  chmod +x "$BASE/tools/mary_dispatcher_health_check.zsh"
  echo "   ✅ Health check restored"
else
  echo "   ⚠️  Health check backup not found (keeping new version)"
fi

# Remove new files (optional - keep for reference)
echo "3. New files (keeping for reference):"
echo "   - tools/mary_alerts_watch.zsh"
echo "   - tools/mary_metrics_collect_daily.zsh"
echo "   (not removed - can be used independently)"

# Remove LaunchAgents
echo "4. Removing LaunchAgents..."
rm -f ~/Library/LaunchAgents/com.02luka.mary.metrics.daily.plist
rm -f ~/Library/LaunchAgents/com.02luka.mary.alerts.plist
echo "   ✅ LaunchAgents removed"

echo ""
echo "✅ Rollback complete"
echo "Run health check: $BASE/tools/mary_dispatcher_health_check.zsh"
