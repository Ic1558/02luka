#!/usr/bin/env zsh
# Rollback Script for Agent Ledger System Deployment
# Usage: deploy_rollback_agent_ledger.zsh [backup_timestamp]
# If backup_timestamp provided, restores from that backup

set -euo pipefail

REPO_ROOT="${LUKA_SOT:-$HOME/02luka}"
BACKUP_TIMESTAMP="${1:-}"

echo "🔄 Agent Ledger System Rollback"
echo "================================="
echo ""

if [[ -n "$BACKUP_TIMESTAMP" ]]; then
  BACKUP_DIR="g/reports/deployments/$BACKUP_TIMESTAMP"
  if [[ ! -d "$BACKUP_DIR" ]]; then
    echo "❌ Backup directory not found: $BACKUP_DIR"
    exit 1
  fi
  echo "📦 Restoring from backup: $BACKUP_TIMESTAMP"
else
  echo "🗑️  Removing Agent Ledger System files..."
fi

# List of files to rollback
FILES_TO_REMOVE=(
  "tools/ledger_write.zsh"
  "tools/status_update.zsh"
  "tools/ledger_schema_validate.zsh"
  "tools/cls_ledger_hook.zsh"
  "tools/cls_session_summary.zsh"
  "tools/andy_ledger_hook.zsh"
  "tools/hybrid_ledger_hook.zsh"
  "docs/AGENT_LEDGER_GUIDE.md"
  "docs/AGENT_LEDGER_SCHEMA.md"
)

# Directories to clean (optional - ledger data might be valuable)
DIRS_TO_CLEAN=(
  "g/ledger"
  "agents/cls/status.json"
  "agents/andy/status.json"
  "agents/hybrid/status.json"
)

if [[ -n "$BACKUP_TIMESTAMP" ]]; then
  # Restore from backup
  echo "Restoring files from backup..."
  for file in "${FILES_TO_REMOVE[@]}"; do
    if [[ -f "$BACKUP_DIR/$file" ]]; then
      mkdir -p "$(dirname "$file")"
      cp "$BACKUP_DIR/$file" "$file"
      echo "  ✅ Restored: $file"
    fi
  done
else
  # Remove files (but keep ledger data)
  echo "Removing Agent Ledger System files..."
  for file in "${FILES_TO_REMOVE[@]}"; do
    if [[ -f "$file" ]]; then
      rm "$file"
      echo "  ✅ Removed: $file"
    fi
  done
  
  echo ""
  echo "⚠️  Note: Ledger data in g/ledger/ is preserved"
  echo "⚠️  Note: Status files in agents/*/ are preserved"
  echo "   (Remove manually if needed)"
fi

echo ""
echo "✅ Rollback complete"
