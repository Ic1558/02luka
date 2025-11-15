#!/usr/bin/env bash
# Lightweight launcher for the Python-based trading CLI backend.
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "$0")" && pwd)
PY_CLI="$SCRIPT_DIR/lib/trading_cli.py"

if ! command -v python3 >/dev/null 2>&1; then
  echo "Error: python3 is required to run $0" >&2
  exit 1
fi

if [[ ! -f "$PY_CLI" ]]; then
  echo "Error: $PY_CLI not found" >&2
  exit 1
fi

exec python3 "$PY_CLI" "$@"
