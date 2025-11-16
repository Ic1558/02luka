#!/usr/bin/env zsh
# Dashboard launcher (hybrid mode - Boss requested)
# Created: 2025-11-17 (Phase 3 restoration)
#
# NOTE: This is a compatibility shim for LaunchAgent com.02luka.dashboard.daily
# The actual dashboard export is handled by dashboard_export.zsh

set -euo pipefail

LOG_FILE="$HOME/02luka/logs/dashboard_shim.log"
mkdir -p "$(dirname "$LOG_FILE")"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] dashboard.zsh compatibility shim called" >> "$LOG_FILE"

# If dashboard_export.zsh exists, delegate to it
if [[ -f "$HOME/02luka/g/tools/dashboard_export.zsh" ]]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Delegating to dashboard_export.zsh" >> "$LOG_FILE"
  exec "$HOME/02luka/g/tools/dashboard_export.zsh" "$@"
fi

# Otherwise, just log that we were called (hybrid mode)
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Dashboard export delegated to hybrid system" >> "$LOG_FILE"
exit 0
