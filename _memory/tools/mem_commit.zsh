#!/usr/bin/env zsh
set -euo pipefail
cd "$(dirname "$0")/.."
git add -A
if ! git diff --cached --quiet; then
  GEN_TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  git -c user.name="02LUKA Memory Bot" \
      -c user.email="bot@02luka.local" \
      commit -m "mem: update entries @ ${GEN_TS}
Created-by: GG_Agent_02luka
Phase: memory-sync"
  git push
else
  echo "No memory changes."
fi
