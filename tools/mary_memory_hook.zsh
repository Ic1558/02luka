#!/usr/bin/env zsh
# ~/02luka/tools/mary.zsh
# Wrapper for Mary Router

set -euo pipefail

LUKA_ROOT="${LUKA_ROOT:-$HOME/02luka}"
export LUKA_ROOT
if [[ $# -lt 2 ]]; then
  echo "Usage: zsh tools/mary.zsh <interactive|background> <path> [op]"
  exit 1
fi

python3 "$LUKA_ROOT/tools/mary_dispatch.py" --source "$1" --path "$2" --op "${3:-write}"
