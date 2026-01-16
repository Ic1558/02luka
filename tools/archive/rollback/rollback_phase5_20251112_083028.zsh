#!/usr/bin/env zsh
set -euo pipefail

# Phase 5 Rollback Script
# Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)

REPO="$HOME/02luka"
BACKUP_DIR="$REPO/g/reports/deploy_backups"

echo "=== Phase 5 Rollback ==="
echo ""

# Find latest backup
LATEST_BACKUP=$(ls -1td "$BACKUP_DIR"/*/ 2>/dev/null | head -1)

if [[ -z "$LATEST_BACKUP" ]]; then
  echo "❌ No backup found"
  exit 1
fi

echo "Using backup: $LATEST_BACKUP"
echo ""

# Restore shared_memory
if [[ -d "$LATEST_BACKUP/shared_memory" ]]; then
  echo "Restoring shared_memory..."
  cp -r "$LATEST_BACKUP/shared_memory"/* "$REPO/shared_memory/" 2>/dev/null || true
  echo "✅ shared_memory restored"
fi

# Restore scripts
echo "Restoring scripts..."
for script in governance_alert_hook.zsh governance_report_generator.zsh certificate_validator.zsh; do
  if [[ -f "$LATEST_BACKUP/$script" ]]; then
    cp "$LATEST_BACKUP/$script" "$REPO/tools/$script"
    chmod +x "$REPO/tools/$script"
    echo "✅ $script restored"
  fi
done

# Unload LaunchAgents (optional - comment out if not needed)
# launchctl unload ~/Library/LaunchAgents/com.02luka.governance.alerts.plist 2>/dev/null || true
# launchctl unload ~/Library/LaunchAgents/com.02luka.governance.report.weekly.plist 2>/dev/null || true

echo ""
echo "✅ Rollback complete"
echo ""
echo "Note: Git rollback available via:"
echo "  git reset --hard HEAD~1"
