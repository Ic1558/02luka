#!/usr/bin/env zsh
# Rollback Script: cancellation_mitigation
# Generated: 2025-11-12T16:56:14Z
# Purpose: Rollback deployment changes

set -euo pipefail

REPO="${LUKA_SOT:-$HOME/02luka}"
cd "$REPO"

BACKUP_DIR="backups/deploy_cancellation_mitigation_20251112_095500"

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" >&2
}

log "🔄 Starting rollback..."

# Verify backup exists
if [[ ! -d "$BACKUP_DIR" ]]; then
  log "❌ Backup directory not found: $BACKUP_DIR"
  exit 1
fi

# Restore CI workflow
if [[ -f "$BACKUP_DIR/ci.yml" ]]; then
  log "Restoring CI workflow..."
  cp "$BACKUP_DIR/ci.yml" ".github/workflows/ci.yml"
fi

# Remove new files (optional - only if causing issues)
# Uncomment if needed:
# log "Removing health_dashboard.cjs..."
# rm -f "run/health_dashboard.cjs"
# 
# log "Removing cancellation analytics..."
# rm -f "tools/gha_cancellation_report.zsh"

log "✅ Rollback complete"
log "Note: New files (health_dashboard.cjs, gha_cancellation_report.zsh) are safe to keep"
log "Only CI workflow was restored to previous state"

exit 0
