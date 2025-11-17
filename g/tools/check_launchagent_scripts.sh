#!/usr/bin/env bash
set -euo pipefail

BASE="${LUKA_SOT:-$HOME/02luka}"
CHECKER="$BASE/g/tools/validate_launchagent_paths.zsh"

if [[ ! -x "$CHECKER" ]]; then
  echo "Missing checker: $CHECKER" >&2
  exit 1
fi

exec "$CHECKER"
