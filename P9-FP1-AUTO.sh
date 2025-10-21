#!/usr/bin/env bash
set -euo pipefail

ROOT="${ROOT:-$HOME/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka/02luka-repo}"
WORKER_DIR="${WORKER_DIR:-$HOME/ops-02luka-worker}"
LOG="$ROOT/g/logs"; mkdir -p "$LOG"

say(){ printf "%s\n" ">>> $*"; }

# 0) Preflight: docker
if ! command -v docker >/dev/null 2>&1; then
  echo "Docker not found. Install/start Docker and re-run."; exit 1
fi
if ! docker info >/dev/null 2>&1; then
  echo "Docker daemon not running. Start Docker and re-run."; exit 1
fi
say "Docker OK"

# 1) Ensure cloudflared
need_cf=0
if ! command -v cloudflared >/dev/null 2>&1; then
  need_cf=1
  if [[ "$OSTYPE" == "darwin"* ]] && command -v brew >/dev/null 2>&1; then
    say "Installing cloudflared via Homebrew..."
    brew install cloudflared
  else
    echo "cloudflared not found."
    echo "Linux quick install (Debian/Ubuntu):"
    echo "  curl -fsSL https://pkg.cloudflare.com/install.sh | sudo bash"
    echo "  sudo apt-get install cloudflared"
    echo "Then re-run this script."
    exit 1
  fi
fi
say "cloudflared OK"

# 2) Repo env
cd "$ROOT"
if [[ ! -f .env ]]; then
  echo ".env not found at $ROOT"; exit 1
fi
set -a; source .env; set +a

# Guard: make sure BRIDGE_TOKEN is set to a non-placeholder
if [[ -z "${BRIDGE_TOKEN:-}" || "$BRIDGE_TOKEN" == "CHANGE_ME_LONG_RANDOM" ]]; then
  say "Generating BRIDGE_TOKEN (random)..."
  BRIDGE_TOKEN="$(python3 - <<'PY'
import secrets; print(secrets.token_hex(32))
PY
)"
  # persist into .env (append or replace)
  if grep -q '^BRIDGE_TOKEN=' .env; then
    sed -i.bak -E "s|^BRIDGE_TOKEN=.*|BRIDGE_TOKEN=${BRIDGE_TOKEN}|g" .env
  else
    printf "\nBRIDGE_TOKEN=%s\n" "$BRIDGE_TOKEN" >> .env
  fi
  say "Updated .env with a new BRIDGE_TOKEN"
fi

# 3) Start compose stack (bridge, redis, etc.)
say "Starting docker compose stack..."
docker compose up -d
say "Waiting for bridge on 127.0.0.1:8788 ..."
timeout=30; ok=0
for i in $(seq $timeout); do
  if curl -fsS -H "x-auth-token: $BRIDGE_TOKEN" http://127.0.0.1:8788/ping >/dev/null; then ok=1; break; fi
  sleep 1
done
if [[ $ok -ne 1 ]]; then
  docker compose logs bridge --tail=200 | tee "$LOG/bridge.start.fail.log" || true
  echo "Bridge did not respond at 127.0.0.1:8788. Check logs above."; exit 1
fi
say "Bridge local OK"

# 4) Fresh TryCloudflare tunnel
say "Starting fresh cloudflared tunnel..."
pkill -f cloudflared >/dev/null 2>&1 || true
nohup cloudflared tunnel --url http://127.0.0.1:8788 > "$LOG/cloudflared.out" 2>&1 &
sleep 2
TUN_URL="$(grep -Eo 'https://[a-z0-9-]+\.trycloudflare\.com' "$LOG/cloudflared.out" | tail -n1 || true)"
if [[ -z "$TUN_URL" ]]; then
  echo "Could not detect tunnel URL in $LOG/cloudflared.out"; tail -n 50 "$LOG/cloudflared.out" || true; exit 1
fi
say "Tunnel: $TUN_URL"
# prove tunnel -> bridge
curl -fsS -H "x-auth-token: $BRIDGE_TOKEN" "$TUN_URL/ping" >/dev/null || { echo "Tunnel ping failed"; exit 1; }
say "Tunnel OK"

# 5) Update Worker secrets
if ! command -v wrangler >/dev/null 2>&1; then
  echo "wrangler not found. Install @cloudflare/wrangler to deploy the Worker, or skip this step." ; exit 1
fi
cd "$WORKER_DIR"
say "Pushing Worker secrets..."
printf "%s" "$TUN_URL" | wrangler secret put BRIDGE_URL --quiet
printf "%s" "$BRIDGE_TOKEN" | wrangler secret put BRIDGE_TOKEN --quiet

# 6) Deploy Worker
say "Deploying Worker..."
wrangler deploy

WURL="$(wrangler deployments list 2>/dev/null | grep -Eo 'https://[a-z0-9-]+\.workers\.dev' | head -n1 || true)"
# fallback to known name if list fails
[[ -z "$WURL" ]] && WURL="https://ops-02luka.ittipong-c.workers.dev"
say "Worker URL: $WURL"

# 7) Validate through Worker
say "Validating via Worker..."
set +e
WPING="$(curl -sS "$WURL/api/ping")"; rc1=$?
WHEALTH="$(curl -sS "$WURL/api/health")"; rc2=$?
WPRED="$(curl -sS "$WURL/api/predict/latest")"; rc3=$?
WFED="$(curl -sS "$WURL/api/federation/ping")"; rc4=$?
set -e

echo "PING   rc=$rc1  body=$WPING"
echo "HEALTH rc=$rc2  body=$(echo "$WHEALTH" | head -c 200)"
echo "PRED   rc=$rc3  body=$(echo "$WPRED" | head -c 200)"
echo "FED    rc=$rc4  body=$WFED"

fail=$(( (rc1!=0) + (rc2!=0) + (rc3!=0) + (rc4!=0) ))
if [[ $fail -gt 0 ]]; then
  echo "Some Worker endpoints failed ($fail). Run: wrangler tail  and re-try."; exit 1
fi

say "All green."
echo "Bridge:  http://127.0.0.1:8788"
echo "Tunnel:  $TUN_URL"
echo "Worker:  $WURL"
