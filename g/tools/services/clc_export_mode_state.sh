#!/usr/bin/env bash
set -euo pipefail
STATE_FILE="${STATE_FILE:-$(dirname "$0")/../../state/clc_export_mode.env}"

ensure_file() {
  if [[ ! -f "$STATE_FILE" ]]; then
    mkdir -p "$(dirname "$STATE_FILE")"
    cat > "$STATE_FILE" <<EOF
MODE=off
LOCAL_DIR=
UPDATED_AT=$(date -u +%FT%TZ)
EOF
  fi
}

cmd="${1:-get}"
case "$cmd" in
  get)
    ensure_file
    cat "$STATE_FILE"
    ;;
  set)
    mode="${2:-off}"
    local_dir="${3:-}"
    case "$mode" in off|local|drive) ;; *) echo "invalid mode"; exit 2;; esac
    ensure_file
    {
      echo "MODE=$mode"
      echo "LOCAL_DIR=$local_dir"
      echo "UPDATED_AT=$(date -u +%FT%TZ)"
    } > "$STATE_FILE.tmp"
    mv -f "$STATE_FILE.tmp" "$STATE_FILE"
    echo "OK set MODE=$mode LOCAL_DIR=$local_dir"
    ;;
  *)
    echo "usage: $0 get|set <off|local|drive> [LOCAL_DIR]"; exit 2;;
esac
