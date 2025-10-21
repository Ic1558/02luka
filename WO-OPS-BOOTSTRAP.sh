#!/usr/bin/env bash
set -euo pipefail

# === 0) Preflight
command -v docker >/dev/null || { echo "Docker required"; exit 1; }
command -v jq >/dev/null || { echo "jq required"; exit 1; }

# === 1) .env (create if missing)
if [[ ! -f .env ]]; then
  TOK="$(openssl rand -hex 24)"
  cat > .env <<ENV
# core
REPO_HOST_PATH=${REPO_HOST_PATH:-$PWD}
TZ=Asia/Bangkok
BRIDGE_TOKEN=${BRIDGE_TOKEN:-$TOK}
REDIS_URL=redis://redis:6379

# ops domain (Worker)
OPS_DOMAIN=${OPS_DOMAIN:-https://ops.theedges.work}

# federation (read-only)
FEDERATION_MODE=readonly
FEDERATION_PEERS=${FEDERATION_PEERS:-$OPS_DOMAIN}
FEDERATION_PEER_TOKENS={}
FEDERATION_TIMEOUT_MS=3000

# feature flags (safe defaults)
OPS_AUDIT_VIEW=on
OPS_DIGEST=on
OPS_CORRELATE_MODE=shadow
PREDICTIVE_MODE=shadow
PREDICTIVE_REPORTS=on
ALLOW_SECRET_EDITS=off
LAB_UI=on
CFG_EDIT=off
CFG_REQUIRE_CONFIRM=on
ENV
  echo "Wrote .env with BRIDGE_TOKEN=$TOK"
else
  echo ".env already exists; leaving as-is."
fi

source .env

# === 2) Start stack
echo "Starting Docker stack…"
docker compose up -d redis bridge clc_listener ops_health ops_alerts ops_daily ops_autoheal || {
  echo "Compose failed"; exit 1; }

# === 3) Wait for bridge (local)
echo "Waiting for bridge on localhost:8788 ..."
for i in {1..30}; do
  if curl -fsS -H "x-auth-token: $BRIDGE_TOKEN" http://127.0.0.1:8788/ping >/dev/null; then
    echo "Bridge is up."
    break
  fi
  sleep 1
  [[ $i -eq 30 ]] && { echo "Bridge not responding"; docker compose logs bridge | tail -n 80; exit 1; }
done

# === 4) Optional: deploy Worker (requires wrangler + files in ~/ops-02luka-worker)
if command -v wrangler >/dev/null && [[ -f "$HOME/ops-02luka-worker/ops-worker.js" ]]; then
  (cd "$HOME/ops-02luka-worker" && wrangler deploy)
else
  echo "Skipping Worker deploy (wrangler or worker files not found)."
fi

# === 5) Smoke tests (local via bridge)
echo "Local bridge tests:"
curl -fsS -H "x-auth-token: $BRIDGE_TOKEN" http://127.0.0.1:8788/state | jq '."clc_export_mode" // .'
curl -fsS -H "x-auth-token: $BRIDGE_TOKEN" http://127.0.0.1:8788/ops-health | jq '.summary // .'

# === 6) If OPS_DOMAIN resolves, test Worker routes
echo "Worker tests (if domain routes to Worker & tunnel is active): $OPS_DOMAIN"
set +e
curl -fsS "$OPS_DOMAIN/api/ping" | jq '.' && ok_ping=1
curl -fsS "$OPS_DOMAIN/api/health" | jq '.summary // .' && ok_health=1
curl -fsS "$OPS_DOMAIN/api/predict/latest" | jq '.json.risk_level,.json.horizon_hours' && ok_predict=1
curl -fsS "$OPS_DOMAIN/api/federation/ping" | jq '.' && ok_fed=1
set -e

echo "Done."
