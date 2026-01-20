#!/usr/bin/env zsh
# ======================================================================
# Work Notes Watcher - Auto-refresh digest on journal changes
# Phase 4: Automation layer for work_notes_digest
# ======================================================================

set -euo pipefail

REPO_ROOT="${LUKA_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || echo "$HOME/02luka")}"
JOURNAL="$REPO_ROOT/g/core_state/work_notes.jsonl"
DIGEST_TOOL="$REPO_ROOT/g/tools/update_work_notes_digest.py"
LINES="${DIGEST_LINES:-200}"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

log_success() {
  echo "${GREEN}✓${NC} $*"
}

log_warn() {
  echo "${YELLOW}⚠${NC} $*"
}

log_error() {
  echo "${RED}✗${NC} $*"
}

# Check if fswatch is available
if ! command -v fswatch &>/dev/null; then
  log_error "fswatch not found. Install via: brew install fswatch"
  log_warn "Falling back to polling mode (5s interval)..."
  POLLING_MODE=true
else
  POLLING_MODE=false
fi

# Ensure journal exists (create empty if missing)
if [[ ! -f "$JOURNAL" ]]; then
  log_warn "Journal not found, creating empty: $JOURNAL"
  mkdir -p "$(dirname "$JOURNAL")"
  touch "$JOURNAL"
fi

# Verify digest tool exists
if [[ ! -f "$DIGEST_TOOL" ]]; then
  log_error "Digest tool not found: $DIGEST_TOOL"
  exit 1
fi

log "🔍 Starting work notes watcher..."
log "   Journal: $JOURNAL"
log "   Digest tool: $DIGEST_TOOL"
log "   Lines: $LINES"
log "   Mode: $([ "$POLLING_MODE" = true ] && echo "Polling (5s)" || echo "fswatch")"
log ""
log "Press Ctrl+C to stop"
log ""

# Function to update digest
update_digest() {
  if python3 "$DIGEST_TOOL" --lines "$LINES" --incremental 2>/dev/null; then
    log_success "Digest updated"
  else
    log_warn "Digest update failed (non-critical)"
  fi
}

# Initial digest update
log "Running initial digest update..."
update_digest

# Cleanup on exit
cleanup() {
  log ""
  log "🛑 Stopping watcher..."
  exit 0
}
trap cleanup INT TERM

# Main watch loop
if [ "$POLLING_MODE" = false ]; then
  # fswatch mode (efficient)
  log_success "Watching with fswatch..."
  fswatch -o "$JOURNAL" | while read -r event; do
    log "📝 Journal changed (event: $event)"
    update_digest
  done
else
  # Polling mode (fallback)
  log_success "Watching with polling..."
  LAST_MTIME=$(stat -f %m "$JOURNAL" 2>/dev/null || echo "0")

  while true; do
    sleep 5
    CURRENT_MTIME=$(stat -f %m "$JOURNAL" 2>/dev/null || echo "0")

    if [[ "$CURRENT_MTIME" != "$LAST_MTIME" ]]; then
      log "📝 Journal changed (mtime: $LAST_MTIME → $CURRENT_MTIME)"
      update_digest
      LAST_MTIME="$CURRENT_MTIME"
    fi
  done
fi
