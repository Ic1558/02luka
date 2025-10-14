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
UI_ROOT="$ROOT_DIR/boss-ui"
if [ ! -d "$UI_ROOT" ]; then echo "[dev-up] ERROR: UI root not found: $UI_ROOT" >&2; exit 1; fi
(
  cd "$UI_ROOT"
export API_BASE="http://127.0.0.1:4000"
  nohup python3 -m http.server "$UI_PORT" --bind 127.0.0.1 >/tmp/boss-ui.out 2>/tmp/boss-ui.err &
)
check_agent_endpoint(){
  local label="$1"
  local endpoint="$2"
  local body="$3"
  local status
  status=$(curl -s -m 5 -o /dev/null -w '%{http_code}' -X POST "http://127.0.0.1:$API_PORT${endpoint}" -H 'Content-Type: application/json' -d "${body}") || status="ERR"
  if [ "${status}" = "200" ]; then
    echo "${label}:UP"
  else
    echo "${label}:DOWN(${status})"
  fi
}

sleep 1
curl -fsS http://127.0.0.1:$API_PORT/api/capabilities >/dev/null && echo "API:UP" || echo "API:DOWN"
check_agent_endpoint "PLAN" "/api/plan" '{"runId":"dev-up","prompt":"health check","files":[]}'
check_agent_endpoint "PATCH" "/api/patch" '{"runId":"dev-up","dryRun":true,"summary":"health check","patches":[{"path":"README.md","diff":"diff --git a/README.md b/README.md\\n"}]}'
check_agent_endpoint "SMOKE" "/api/smoke" '{"runId":"dev-up","mode":"health-check","scope":["api"],"checks":[]}'
curl -fsSI http://127.0.0.1:$UI_PORT/apps/landing.html >/dev/null && echo "UI Landing:UP" || echo "UI Landing:DOWN"
curl -fsSI http://127.0.0.1:$UI_PORT/luka.html >/dev/null && echo "UI Legacy:UP" || echo "UI Legacy:DOWN"
echo "Open: http://127.0.0.1:$UI_PORT/apps/landing.html"
