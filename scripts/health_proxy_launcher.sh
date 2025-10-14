#!/usr/bin/env bash
# LaunchAgent-compatible launcher for health_proxy
# Runs from repo (LaunchAgent permissions OK) using SOT health_proxy.js
set -euo pipefail

# Source universal path resolver
source "$(dirname "$0")/repo_root_resolver.sh"

# Derive SOT_PATH from REPO_ROOT (removes /02luka-repo suffix)
# Example: .../My Drive/02luka/02luka-repo → .../My Drive/02luka
SOT_PATH="${SOT_PATH:-${REPO_ROOT%/02luka-repo}}"
HEALTH_PROXY_JS="$SOT_PATH/gateway/health_proxy.js"
LOG_DIR="$HOME/Library/Logs/02luka"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Verify health_proxy.js exists
if [[ ! -f "$HEALTH_PROXY_JS" ]]; then
    echo "ERROR: health_proxy.js not found at: $HEALTH_PROXY_JS" >&2
    exit 1
fi

# Export environment variables
export HEALTH_PORT="${HEALTH_PORT:-3002}"
export HEALTH_TOKEN="${HEALTH_TOKEN:-02luka-health-default}"
export NODE_ENV="${NODE_ENV:-production}"
export SOT_PATH

# Change to a safe working directory (repo, not Drive)
cd "$REPO_ROOT"

# Run health proxy
# Note: Node can read the .js file from Drive even if cd into Drive fails
exec node "$HEALTH_PROXY_JS"
