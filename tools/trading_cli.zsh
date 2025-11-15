#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "$0")" && pwd)
PY_CLI="$SCRIPT_DIR/lib/trading_cli.py"

if [[ ! -f "$PY_CLI" ]]; then
  echo "Error: $PY_CLI not found" >&2
  exit 1
fi

exec python3 "$PY_CLI" "$@"
