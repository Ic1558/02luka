#!/usr/bin/env zsh
set -euo pipefail
REPO="$HOME/02luka"; cd "$REPO"
# Scan and heal if needed (Phase 2 installed run/auto_heal.cjs)
if [[ -f run/auto_heal.cjs ]]; then
  /opt/homebrew/bin/node run/auto_heal.cjs >> g/logs/autoheal.log 2>&1 || true
fi
