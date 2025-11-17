#!/usr/bin/env zsh
# Wrapper for mls_cursor_watcher.zsh
set -euo pipefail

SCRIPT_PATH="/Users/icmini/02luka/tools/mls_cursor_watcher.zsh"

if [[ ! -f "$SCRIPT_PATH" ]]; then
  echo "ERROR: Script not found at $SCRIPT_PATH" >&2
  exit 1
fi

exec zsh "$SCRIPT_PATH" "$@"
