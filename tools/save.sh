#!/usr/bin/env zsh
# tools/save.sh
# Universal Gateway for 02luka Save System
# Forwards requests to backend (session_save.zsh) with telemetry context.

set -e

# Resolve paths
SCRIPT_DIR=$(dirname "$0")
BACKEND_SCRIPT="$SCRIPT_DIR/session_save.zsh"

# Set source context if not already set
if [[ -z "${SAVE_SOURCE}" ]]; then
    export SAVE_SOURCE="manual"
fi

# Pass arguments as topic/summary if provided
# In the legacy save.sh, $1 might be a flag or text.
# For this gateway, we pass args through to the environment or flags expected by session_save.zsh
# But session_save.zsh primarily reads MLS ledger.
# If arguments are provided, we can map them to TELEMETRY_TOPIC or pass them along.

if [[ $# -gt 0 ]]; then
    export TELEMETRY_TOPIC="$*"
fi

# Execute backend
if [[ -f "$BACKEND_SCRIPT" ]]; then
    exec "$BACKEND_SCRIPT" "$@"
else
    echo "❌ Error: Save backend not found at $BACKEND_SCRIPT"
    exit 1
fi
