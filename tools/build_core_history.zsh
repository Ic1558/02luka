#!/usr/bin/env zsh
set -euo pipefail

# Thin wrapper: Seatbelt-safe (no here-doc execution).
# All logic lives in tools/build_core_history_engine.py

REPO="${REPO_ROOT:-$HOME/02luka}"
cd "$REPO"

exec python3 tools/build_core_history_engine.py "$@"
