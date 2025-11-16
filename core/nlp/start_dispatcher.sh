#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_BIN="${PYTHON_BIN:-python3}"
LOG_DIR="${KIM_DISPATCH_LOG_DIR:-$HOME/02luka/logs}"
mkdir -p "$LOG_DIR"

exec "$PYTHON_BIN" "$SCRIPT_DIR/nlp_command_dispatcher.py" "$@"
