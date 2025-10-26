#!/usr/bin/env bash
# 02LUKA Nightly Optimizer Wrapper Script
set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$REPO_ROOT/g/telemetry"
OPTIMIZER_SCRIPT="$REPO_ROOT/knowledge/optimize/nightly_optimizer.cjs"

# Ensure directories exist
mkdir -p "$LOG_DIR"

# Set up environment
export NODE_NO_WARNINGS=1
export NODE_ENV="${NODE_ENV:-production}"

# Load Redis configuration
if [[ -f "$REPO_ROOT/02luka/config/redis.env" ]]; then
    source "$REPO_ROOT/02luka/config/redis.env"
fi

# Log execution
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting nightly optimizer..."

# Check safety conditions
if ! node "$REPO_ROOT/knowledge/util/safety_checks.cjs" | grep -q '"canProceed":true'; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Safety checks failed - skipping optimization"
    exit 0
fi

# Create schema backup
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Creating schema backup..."
node "$REPO_ROOT/knowledge/util/safety_checks.cjs" --backup

# Run optimizer
if node "$OPTIMIZER_SCRIPT" --telemetry "$REPO_ROOT/g/telemetry/latest_rollup.ndjson"; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Nightly optimizer completed successfully"
    # Reset failure count on success
    node "$REPO_ROOT/knowledge/util/safety_checks.cjs" --reset-failures
    exit 0
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Nightly optimizer failed"
    # Increment failure count
    node "$REPO_ROOT/knowledge/util/safety_checks.cjs" --increment-failure
    exit 1
fi
