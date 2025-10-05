#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
API_PORT="${PORT:-4000}"
UI_PORT="${UI_PORT:-5173}"
cd "$ROOT_DIR"
kill_on_port(){ local p="$1"; lsof -ti tcp:"$p" >/dev/null 2>&1 && lsof -ti tcp:"$p" | xargs -r kill -9 || true; }
kill_on_port "$API_PORT"; kill_on_port "$UI_PORT"
mkdir -p "$ROOT_DIR/boss-api/data"
nohup node "$ROOT_DIR/boss-api/server.cjs" >/tmp/boss-api.out 2>/tmp/boss-api.err &
UI_ROOT="$ROOT_DIR/boss-ui/public"
if [ ! -d "$UI_ROOT" ]; then echo "[dev-up] ERROR: UI root not found: $UI_ROOT" >&2; exit 1; fi
(
  cd "$UI_ROOT"
  nohup python3 -m http.server "$UI_PORT" --bind 127.0.0.1 >/tmp/boss-ui.out 2>/tmp/boss-ui.err &
)
sleep 1
curl -fsS http://127.0.0.1:$API_PORT/api/capabilities >/dev/null && echo "API:UP" || echo "API:DOWN"
curl -fsSI http://127.0.0.1:$UI_PORT/luka.html >/dev/null && echo "UI:UP" || echo "UI:DOWN"
echo "Open: http://127.0.0.1:$UI_PORT/luka.html"
