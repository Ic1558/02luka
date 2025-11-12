#!/usr/bin/env zsh
# Rollback script for Update Workflow cancellation fix
# Generated: 2025-11-12
# Feature: update workflow cancellation mitigation

set -euo pipefail

REPO="${LUKA_SOT:-$HOME/02luka}"
WORKFLOW_FILE="$REPO/.github/workflows/update.yml"
BACKUP_DIR="${1:-backups/update_workflow_backup}"

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" >&2
}

log "=== Rolling back Update Workflow Fix ==="

# Step 1: Check if backup exists
if [[ -d "$BACKUP_DIR" ]]; then
  BACKUP_FILE=$(find "$BACKUP_DIR" -name "update_workflow_backup_*.diff" | head -1)
  if [[ -n "$BACKUP_FILE" && -f "$BACKUP_FILE" ]]; then
    log "📋 Found backup: $BACKUP_FILE"
    log "⚠️  Manual restore required:"
    log "   1. Review backup: $BACKUP_FILE"
    log "   2. Restore: git checkout .github/workflows/update.yml"
    log "   3. Or apply: git apply $BACKUP_FILE"
  else
    log "⚠️  No backup file found in $BACKUP_DIR"
  fi
else
  log "⚠️  Backup directory not found: $BACKUP_DIR"
fi

# Step 2: Manual rollback instructions
log ""
log "📋 Manual Rollback Steps:"
log "   1. Revert the change:"
log "      sed -i.bak 's/cancel-in-progress: false/cancel-in-progress: true/' $WORKFLOW_FILE"
log ""
log "   2. Or restore from git:"
log "      git checkout HEAD~1 -- .github/workflows/update.yml"
log ""
log "   3. Commit and push:"
log "      git add .github/workflows/update.yml"
log "      git commit -m 'revert: update workflow cancellation fix'"
log "      git push origin main"

log ""
log "✅ Rollback instructions provided"

