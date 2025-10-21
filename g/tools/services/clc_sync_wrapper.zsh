#!/usr/bin/env zsh
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
STATE_FILE="$ROOT_DIR/g/state/clc_export_mode.env"
SYNC="$ROOT_DIR/knowledge/sync.cjs"

# defaults
MODE="drive"
LOCAL_DIR=""

# read state if exists
if [[ -f "$STATE_FILE" ]]; then
  source "$STATE_FILE"
  MODE="${MODE:-drive}"
  LOCAL_DIR="${LOCAL_DIR:-}"
fi

case "$MODE" in
  off)
    KNOW_EXPORT_MODE=off node "$SYNC"
    ;;
  local)
    KNOW_EXPORT_MODE=local KNOW_EXPORT_DIR="${LOCAL_DIR:-$ROOT_DIR/.exports_local}" node "$SYNC"
    ;;
  drive)
    KNOW_EXPORT_MODE=drive node "$SYNC"
    ;;
  *)
    echo "Invalid MODE in state: $MODE"; exit 2;;
esac
