#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "$0")" && pwd)
BASE="${LUKA_SOT:-$HOME/02luka}"
VALIDATOR="$SCRIPT_DIR/validate_launchagent_paths.zsh"

if [[ ! -x "$VALIDATOR" ]]; then
  echo "Validator not executable: $VALIDATOR" >&2
  exit 1
fi

"$VALIDATOR"
