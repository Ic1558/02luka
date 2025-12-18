#!/usr/bin/env zsh
# @created_by: CLS
# @purpose: Auto-commit changes on ai/ branch only (with dry-run support)
# @safety: Never touches main branch, never auto-pushes

set -euo pipefail

# Configuration
REPO_DIR="${LUKA_HOME:-$HOME/02luka/g}"
LOG_DIR="$HOME/02luka/g/logs/git_sync"
LOG_FILE="$LOG_DIR/auto_commit_$(date +%Y%m%d).log"
DRY_RUN="${DRY_RUN:-0}"
PAUSE_FLAG="$HOME/02luka/g/.git_auto_sync_paused"

# Check if auto-sync is paused
if [[ -f "$PAUSE_FLAG" ]]; then
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Auto-sync is PAUSED. Remove $PAUSE_FLAG to re-enable." | tee -a "$LOG_DIR/auto_commit_$(date +%Y%m%d).log"
    exit 0
fi

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Error function
error_exit() {
    log "ERROR: $*"
    exit 1
}

# Change to repo directory
cd "$REPO_DIR" || error_exit "Cannot access repo directory: $REPO_DIR"

# Check current branch
CURRENT_BRANCH=$(git branch --show-current)
log "Current branch: $CURRENT_BRANCH"

# Safety check: Must be on ai/ branch
if [[ ! "$CURRENT_BRANCH" =~ ^ai/ ]]; then
    error_exit "Not on ai/ branch. Current: $CURRENT_BRANCH. Aborting for safety."
fi

# Safety check: Never touch main branch
if [[ "$CURRENT_BRANCH" == "main" ]]; then
    error_exit "Attempted to sync main branch. This is forbidden. Aborting."
fi

# Check for uncommitted changes
if git diff --quiet && git diff --cached --quiet; then
    log "No changes to commit. Exiting."
    exit 0
fi

# Check for SOT files in changes (warn but don't block)
SOT_FILES=$(git status --short | grep -E "(core/|CLC/|docs/|02luka\.md)" || true)
if [[ -n "$SOT_FILES" ]]; then
    log "WARNING: SOT files detected in changes:"
    echo "$SOT_FILES" | while read -r line; do
        log "  $line"
    done
    log "Proceeding with caution..."
fi

# Generate commit message
COMMIT_MSG="chore(ai): Auto-commit work in progress - $(date '+%Y-%m-%d %H:%M:%S %z')"

# Show what would be committed
log "Changes to be committed:"
git status --short | while read -r line; do
    log "  $line"
done

if [[ "$DRY_RUN" == "1" ]]; then
    log "DRY-RUN MODE: Would commit with message: $COMMIT_MSG"
    log "DRY-RUN: No actual commit performed."
    exit 0
fi

# Perform commit
log "Committing changes..."
if git commit -m "$COMMIT_MSG"; then
    log "✅ Commit successful"
    COMMIT_SHA=$(git rev-parse --short HEAD)
    log "Commit SHA: $COMMIT_SHA"
else
    error_exit "Commit failed"
fi

log "✅ Auto-commit completed successfully"
