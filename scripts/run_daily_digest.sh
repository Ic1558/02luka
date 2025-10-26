#!/usr/bin/env bash
# 02LUKA Daily Digest Wrapper Script
set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$REPO_ROOT/g/logs"
DIGEST_SCRIPT="$REPO_ROOT/g/tools/services/daily_digest.cjs"

# Ensure directories exist
mkdir -p "$LOG_DIR"

# Set up environment
export NODE_NO_WARNINGS=1
export NODE_ENV="${NODE_ENV:-production}"

# Log execution
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting daily digest..."

# Run digest script
if node "$DIGEST_SCRIPT" --since 24h; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Daily digest completed successfully"
    exit 0
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Daily digest failed" >&2
    exit 1
fi
