#!/usr/bin/env zsh
set -euo pipefail

SRC="$HOME/02luka"
DST="$HOME/gd/02luka_sync/current"
LOG="$HOME/02luka/logs/backup_to_gdrive_run.log"
CONFLICT_RESOLVER="$HOME/02luka/tools/resolve_gdrive_conflicts.zsh"

mkdir -p "$DST" "$(dirname "$LOG")"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting two-way sync..." | tee -a "$LOG"

# Directories to sync
INCLUDE_DIRS=(
  "g"
  "CLC"
  "manuals"
  "docs"
  "scripts"
  "agents"
  "bridge"
  "tools"
)

# Aggressive excludes
EXCLUDES=(
  ".DS_Store" "Thumbs.db"
  ".venv" "venv" "__pycache__"
  "node_modules" ".cache"
  "logs" "artifacts" "_import_logs"
  "memory/autosave"
  "*.log" "*.tmp" "*.bak" "*.swp" "*.lock"
  "*.iso" "*.dmg"
)

rsync_args=(-avhu --update)
for e in "${EXCLUDES[@]}"; do rsync_args+=(--exclude "$e"); done

# Phase 1: Pull changes from GD → Local (mobile edits)
echo "[sync] Phase 1: Pull from GD → Local" | tee -a "$LOG"
for d in "${INCLUDE_DIRS[@]}"; do
  [[ -d "$DST/$d" ]] || continue
  mkdir -p "$SRC/$d"
  echo "[pull] $DST/$d -> $SRC/$d" | tee -a "$LOG"
  rsync "${rsync_args[@]}" "$DST/$d/" "$SRC/$d/" 2>&1 | tee -a "$LOG"
done

# Phase 2: Check for conflicts
if [[ -x "$CONFLICT_RESOLVER" ]]; then
  echo "[sync] Phase 2: Conflict check" | tee -a "$LOG"
  "$CONFLICT_RESOLVER" 2>&1 | tee -a "$LOG"
fi

# Phase 3: Push changes from Local → GD (local edits)
echo "[sync] Phase 3: Push from Local → GD" | tee -a "$LOG"
for d in "${INCLUDE_DIRS[@]}"; do
  [[ -d "$SRC/$d" ]] || continue
  mkdir -p "$DST/$d"
  echo "[push] $SRC/$d -> $DST/$d" | tee -a "$LOG"
  rsync "${rsync_args[@]}" "$SRC/$d/" "$DST/$d/" 2>&1 | tee -a "$LOG"
done

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Two-way sync complete" | tee -a "$LOG"
