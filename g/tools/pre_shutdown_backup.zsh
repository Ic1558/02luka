#!/usr/bin/env zsh
# Pre-Shutdown Backup
# Backup critical files before system shutdown/restart
set -euo pipefail

BASE="$HOME/02luka"
BACKUP_DIR="$BASE/backups/pre_shutdown"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

echo "📦 Pre-shutdown backup starting..."

# Backup critical directories
CRITICAL_DIRS=(
  "mls/ledger"
  "mls/status"
  "g/reports"
  "bridge/inbox"
  "tools"
)

for dir in "${CRITICAL_DIRS[@]}"; do
  if [[ -d "$BASE/$dir" ]]; then
    echo "  Backing up: $dir"
    tar -czf "$BACKUP_DIR/${dir//\//_}_${TIMESTAMP}.tar.gz" -C "$BASE" "$dir" 2>/dev/null || true
  fi
done

# Commit any uncommitted changes
if [[ -f "$BASE/tools/auto_commit_work.zsh" ]]; then
  echo "  Auto-committing uncommitted changes..."
  "$BASE/tools/auto_commit_work.zsh" || true
fi

# Push to remote
if [[ -f "$BASE/tools/ensure_remote_sync.zsh" ]]; then
  echo "  Ensuring remote sync..."
  "$BASE/tools/ensure_remote_sync.zsh" || true
fi

echo "✅ Pre-shutdown backup complete: $BACKUP_DIR"

