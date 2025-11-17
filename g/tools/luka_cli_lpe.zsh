#!/usr/bin/env zsh
set -euo pipefail

BASE="${LUKA_SOT:-$HOME/02luka}"
CLI="$BASE/tools/luka_cli.zsh"

if [[ ! -x "$CLI" ]]; then
  echo "Luka CLI not found at $CLI" >&2
  exit 1
fi

exec "$CLI" lpe-apply "$@"
