#!/usr/bin/env zsh
set -euo pipefail

# Rollback script for Phase 6 Week 1 deployment (2025-11-13)
# Restores adaptive collector, dashboard generator, proposal generator,
# LaunchAgents, and dashboard HTML from backup.

BACKUP_DIR="$HOME/02luka/g/reports/deploy_backups/20251113_073330_phase6_week1"
TARGET_DIR="$HOME/02luka"

if [[ ! -d "$BACKUP_DIR" ]]; then
  echo "❌ Backup directory not found: $BACKUP_DIR" >&2
  exit 1
fi

echo "Restoring files from $BACKUP_DIR ..."

cp "$BACKUP_DIR/adaptive_collector.zsh" "$TARGET_DIR/tools/adaptive_collector.zsh"
cp "$BACKUP_DIR/dashboard_generator.zsh" "$TARGET_DIR/tools/dashboard_generator.zsh"
cp "$BACKUP_DIR/adaptive_proposal_gen.zsh" "$TARGET_DIR/tools/adaptive_proposal_gen.zsh"
cp "$BACKUP_DIR/memory_daily_digest.zsh" "$TARGET_DIR/tools/memory_daily_digest.zsh"
cp "$BACKUP_DIR/index.html" "$TARGET_DIR/g/reports/dashboard/index.html"
cp "$BACKUP_DIR/com.02luka.adaptive.collector.daily.plist" "$TARGET_DIR/LaunchAgents/com.02luka.adaptive.collector.daily.plist"
cp "$BACKUP_DIR/com.02luka.adaptive.proposal.gen.plist" "$TARGET_DIR/LaunchAgents/com.02luka.adaptive.proposal.gen.plist"

echo "✔️  Files restored."
echo "Reminder: reload LaunchAgents if needed:"
echo "  launchctl unload ~/Library/LaunchAgents/com.02luka.adaptive.collector.daily.plist"
echo "  launchctl load   ~/Library/LaunchAgents/com.02luka.adaptive.collector.daily.plist"
echo "  launchctl unload ~/Library/LaunchAgents/com.02luka.adaptive.proposal.gen.plist"
echo "  launchctl load   ~/Library/LaunchAgents/com.02luka.adaptive.proposal.gen.plist"
