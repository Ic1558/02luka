#!/usr/bin/env zsh
set -euo pipefail

# Rollback Phase 6 Simplified Deployment
# Restores backed up scripts and unloads LaunchAgents

REPO="$HOME/02luka"
cd "$REPO"

BACKUP_DIR="backups/deploy_phase6_20251112_152746"

echo "== Unloading LaunchAgents =="
for plist in com.02luka.adaptive.collector.daily com.02luka.adaptive.proposal.gen; do
  PLIST="$HOME/Library/LaunchAgents/${plist}.plist"
  if [[ -f "$PLIST" ]]; then
    launchctl unload "$PLIST" 2>/dev/null || true
    rm -f "$PLIST"
    echo "Unloaded: $plist"
  fi
done

echo "== Restoring backed up scripts =="
if [[ -d "$BACKUP_DIR" ]]; then
  for script in adaptive_collector.zsh adaptive_proposal_gen.zsh weekly_recap_generator.zsh; do
    if [[ -f "$BACKUP_DIR/$script" ]]; then
      cp "$BACKUP_DIR/$script" "tools/$script"
      echo "Restored: $script"
    fi
  done
else
  echo "⚠️  Backup directory not found: $BACKUP_DIR"
  echo "⚠️  Manual restoration required"
fi

echo "== Done =="
