#!/usr/bin/env zsh
set -euo pipefail
ROOT="${1:-$HOME/02luka/web/hub-quicken}"
PORT="${PORT:-8090}"
cd "$ROOT"
echo "Serving Hub Quicken at http://localhost:${PORT}/web/hub-quicken/"
if command -v python3 >/dev/null 2>&1; then
  # serve from repo root to keep ../../hub/* paths working
  cd ../.. && exec python3 -m http.server "$PORT"
else
  echo "need python3"; exit 127
fi
