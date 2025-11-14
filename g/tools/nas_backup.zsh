#!/usr/bin/env zsh
set -euo pipefail

# Smart NAS Backup with 7-day rotation
# Backs up ~/02luka to external NAS/drive with incremental rsync

REPO="$HOME/02luka"
LOG="$REPO/logs/nas_backup.log"
DRY_RUN="${DRY_RUN:-0}"  # Set DRY_RUN=1 for dry-run mode

# Auto-detect NAS/backup destination
detect_backup_dest() {
  # Check for common backup volumes (no glob expansion)
  local candidates=(
    "/Volumes/lukadata"
    "/Volumes/Past Works"
  )

  # Add any "Backups of" volumes
  for vol in /Volumes/*; do
    [[ "$vol" =~ "Backups of" ]] && candidates+=("$vol")
    [[ "$vol" =~ "Seagate" ]] && candidates+=("$vol")
    [[ "$vol" =~ "Backup" ]] && candidates+=("$vol")
  done

  # Check each candidate
  for path in "${candidates[@]}"; do
    if [[ -d "$path" ]]; then
      echo "$path/02luka_backup"
      return 0
    fi
  done

  # No backup volume found
  echo "ERROR: No backup volume mounted" >&2
  echo "Available volumes:" >&2
  ls -1 /Volumes/ | grep -v "Macintosh HD" >&2
  return 1
}

ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
log() { echo "[$(ts)] $*" | tee -a "$LOG"; }

BACKUP_DEST=$(detect_backup_dest) || exit 1
TODAY=$(date +%Y%m%d)
BACKUP_DIR="$BACKUP_DEST/$TODAY"
LATEST_LINK="$BACKUP_DEST/latest"

log "=== NAS Backup Started ==="
log "Source: $REPO"
log "Destination: $BACKUP_DIR"
log "Dry-run: $DRY_RUN"

# Create backup directory
if (( DRY_RUN == 0 )); then
  mkdir -p "$BACKUP_DIR"
fi

# Rsync with incremental hard-link backup
RSYNC_OPTS=(
  -avh
  --delete
  --exclude='.git'
  --exclude='node_modules'
  --exclude='logs/*.log'
  --exclude='.DS_Store'
  --exclude='*.tmp'
  --exclude='.cache'
)

# Use previous backup for hard-links (saves space)
if [[ -d "$LATEST_LINK" ]]; then
  RSYNC_OPTS+=(--link-dest="$LATEST_LINK")
  log "Incremental backup from: $LATEST_LINK"
else
  log "Full backup (no previous backup found)"
fi

if (( DRY_RUN )); then
  RSYNC_OPTS+=(--dry-run)
fi

# Perform backup
log "Running rsync..."
if rsync "${RSYNC_OPTS[@]}" "$REPO/" "$BACKUP_DIR/"; then
  log "✅ Backup completed successfully"

  if (( DRY_RUN == 0 )); then
    # Update 'latest' symlink
    rm -f "$LATEST_LINK"
    ln -s "$BACKUP_DIR" "$LATEST_LINK"
    log "Updated latest link"
  fi
else
  log "❌ Backup failed (exit $?)"
  exit 1
fi

# Cleanup: Keep only last 7 days
if (( DRY_RUN == 0 )); then
  log "Cleaning up old backups (keep 7 days)..."
  find "$BACKUP_DEST" -maxdepth 1 -type d -name "202[0-9][0-9][0-9][0-9][0-9]" -mtime +7 -exec rm -r -f {} \; 2>/dev/null || true

  KEPT=$(find "$BACKUP_DEST" -maxdepth 1 -type d -name "202[0-9][0-9][0-9][0-9][0-9]" | wc -l | xargs)
  log "Backups kept: $KEPT"
fi

# Report size
BACKUP_SIZE=$(du -sh "$BACKUP_DIR" 2>/dev/null | awk '{print $1}' || echo "unknown")
log "Backup size: $BACKUP_SIZE"
log "=== Backup Complete ==="
