#!/usr/bin/env bash
# LaunchAgent-compatible wrapper for automated_discovery_merge.sh
# Executes from repo (LaunchAgent permissions OK) but calls SOT script
set -euo pipefail

# SOT path (where actual script lives)
SOT_PATH="${SOT_PATH:-$HOME/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka}"
export SOT_PATH

# Real script location in SOT
REAL_SCRIPT="$SOT_PATH/g/tools/automated_discovery_merge.sh"

# Verify real script exists
if [[ ! -f "$REAL_SCRIPT" ]]; then
    echo "ERROR: Real script not found at: $REAL_SCRIPT" >&2
    exit 1
fi

# Verify script is executable
if [[ ! -x "$REAL_SCRIPT" ]]; then
    echo "ERROR: Script not executable: $REAL_SCRIPT" >&2
    exit 1
fi

# Execute real script with all arguments
exec /bin/bash "$REAL_SCRIPT" "$@"
