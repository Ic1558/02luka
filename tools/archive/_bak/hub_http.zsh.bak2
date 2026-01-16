#!/usr/bin/env zsh
set -euo pipefail
PORT="${HUB_PORT:-8080}"
ROOT="${1:-$HOME/02luka}"
cd "$ROOT"
echo "Serving $PWD at http://localhost:${PORT}/ (Ctrl+C to stop)"
# Prefer Python http.server
if command -v python3 >/dev/null 2>&1; then
  exec python3 -m http.server "$PORT"
elif command -v php >/dev/null 2>&1; then
  exec php -S "127.0.0.1:${PORT}"
else
  echo "No simple HTTP server found (need python3 or php)"; exit 127
fi
