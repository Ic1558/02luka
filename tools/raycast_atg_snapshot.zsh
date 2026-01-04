#!/usr/bin/env zsh

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title ATG
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 📸
# @raycast.packageName 02LUKA Ops
# @raycast.description Run ATG Snapshot and open result
# @raycast.author Boss
# @raycast.authorURL https://02luka.local
# @raycast.argument1 { "type": "dropdown", "data": [{"title":"normal","value":"normal"},{"title":"archive","value":"archive"}], "optional": true }

set -euo pipefail

# Configuration (Autodetected or Hardcoded)
PROJECT_DIR="$HOME/02luka"
SNAP_TOOL="$PROJECT_DIR/tools/atg_snap.zsh"
SNAPSHOT_FILE="$PROJECT_DIR/magic_bridge/inbox/atg_snapshot.md" # Updated path
MODE="${1:-normal}"

if [[ ! -f "$SNAP_TOOL" ]]; then
  echo "⚠️ Tool not found: $SNAP_TOOL"
  exit 1
fi

# keep mtime before run (detect fresh write)
prev_mtime="0"
if [[ -f "$SNAPSHOT_FILE" ]]; then # Use SNAPSHOT_FILE
  # BSD/Mac stat
  prev_mtime="$(stat -f %m "$SNAPSHOT_FILE" 2>/dev/null || echo 0)"
fi

echo "📸 Snapping..."
cd "$PROJECT_DIR"

# run snapshot
"$SNAP_TOOL" >/dev/null 2>&1 || {
  echo "❌ Snapshot Failed"
  exit 1
}

# validate fresh + non-empty
if [[ ! -s "$SNAPSHOT_FILE" ]]; then
  echo "❌ Snapshot empty/missing: $SNAPSHOT_FILE"
  exit 1
fi

# Check freshness
new_mtime="$(stat -f %m "$SNAPSHOT_FILE" 2>/dev/null || echo 0)"
# Note: we use -le because sometimes execution is so fast mtime doesn't shift if precision is low, 
# but usually it should update. 
if [[ "$new_mtime" -eq "$prev_mtime" ]]; then
  echo "⚠️ (Warning: File mtime matches previous)"
fi

# optional archive copy (timestamped)
if [[ "$MODE" == "archive" ]]; then
  ts="$(date +%Y%m%d_%H%M%S)"
  ARCH_DIR="$PROJECT_DIR/magic_bridge/archive"
  mkdir -p "$ARCH_DIR"
  cp -f "$SNAPSHOT_FILE" "$ARCH_DIR/atg_snapshot_${ts}.md"
  echo "📦 Archived to ${ts}"
fi

echo "✅ Snapshot Done!"

# Copy to clipboard (UTF-8)
if command -v pbcopy >/dev/null 2>&1; then
  cat "$SNAPSHOT_FILE" | pbcopy
  echo "📋 Copied to clipboard"
fi

open "$SNAPSHOT_FILE"
