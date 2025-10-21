#!/usr/bin/env bash
set -euo pipefail

# P9-FP1-TUNNEL-RESUME.sh - Automated tunnel fix for Phase 9.0
# Handles cloudflared tunnel creation, URL extraction, and Worker update

ROOT="$(pwd)"
WORKER_DIR="$HOME/ops-02luka-worker"
LOG="$ROOT/g/logs"
mkdir -p "$LOG"

say() { printf "%s\n" ">>> $*"; }
fail() { echo "ERROR: $*" >&2; exit 1; }

# Load environment
if [[ ! -f .env ]]; then
  fail ".env not found at $ROOT"
fi
set -a; source .env; set +a

# Verify prerequisites
command -v cloudflared >/dev/null || fail "cloudflared not found"
command -v wrangler >/dev/null || fail "wrangler not found"
command -v curl >/dev/null || fail "curl not found"

# Verify bridge is running
if ! curl -fsS -H "x-auth-token: $BRIDGE_TOKEN" http://127.0.0.1:8788/ping >/dev/null; then
  fail "Bridge not responding at 127.0.0.1:8788"
fi
say "Bridge local OK"

# Kill any existing cloudflared processes
pkill -f cloudflared >/dev/null 2>&1 || true
sleep 1

# Function to extract tunnel URL from cloudflared output
extract_tunnel_url() {
  local log_file="$1"
  local timeout=30
  local count=0
  
  while [[ $count -lt $timeout ]]; do
    if [[ -f "$log_file" ]]; then
      local url=$(grep -Eo 'https://[a-z0-9-]+\.trycloudflare\.com' "$log_file" | tail -n1)
      if [[ -n "$url" ]]; then
        echo "$url"
        return 0
      fi
    fi
    sleep 1
    ((count++))
  done
  
  return 1
}

# Start cloudflared tunnel in background
say "Starting cloudflared tunnel..."
TUNNEL_LOG="$LOG/cloudflared-tunnel.log"
nohup cloudflared tunnel --url http://127.0.0.1:8788 > "$TUNNEL_LOG" 2>&1 &
TUNNEL_PID=$!

# Wait for tunnel URL
say "Waiting for tunnel URL..."
TUN_URL=""
for i in {1..30}; do
  TUN_URL=$(extract_tunnel_url "$TUNNEL_LOG")
  if [[ -n "$TUN_URL" ]]; then
    say "Tunnel URL: $TUN_URL"
    break
  fi
  sleep 1
done

if [[ -z "$TUN_URL" ]]; then
  kill $TUNNEL_PID 2>/dev/null || true
  echo "Could not extract tunnel URL from:"
  tail -n 20 "$TUNNEL_LOG" || true
  fail "Tunnel URL extraction failed"
fi

# Test tunnel connectivity
say "Testing tunnel connectivity..."
if ! curl -fsS -H "x-auth-token: $BRIDGE_TOKEN" "$TUN_URL/ping" >/dev/null; then
  kill $TUNNEL_PID 2>/dev/null || true
  fail "Tunnel ping failed"
fi
say "Tunnel OK"

# Update Worker secrets
say "Updating Worker secrets..."
cd "$WORKER_DIR"
printf "%s" "$TUN_URL" | wrangler secret put BRIDGE_URL --quiet
printf "%s" "$BRIDGE_TOKEN" | wrangler secret put BRIDGE_TOKEN --quiet
say "Worker secrets updated"

# Redeploy Worker
say "Redeploying Worker..."
wrangler deploy
say "Worker redeployed"

# Get Worker URL
WURL="https://ops-02luka.ittipong-c.workers.dev"
say "Worker URL: $WURL"

# Validate end-to-end
say "Validating end-to-end connectivity..."
set +e
WPING="$(curl -sS "$WURL/api/ping" 2>/dev/null)"
WHEALTH="$(curl -sS "$WURL/api/health" 2>/dev/null)"
WPRED="$(curl -sS "$WURL/api/predict/latest" 2>/dev/null)"
WFED="$(curl -sS "$WURL/api/federation/ping" 2>/dev/null)"
set -e

echo ""
echo "=== Validation Results ==="
echo "PING:   $WPING"
echo "HEALTH: $(echo "$WHEALTH" | head -c 100)..."
echo "PRED:   $(echo "$WPRED" | head -c 100)..."
echo "FED:    $WFED"

# Check if ping works
if echo "$WPING" | grep -q '"ok":true'; then
  say "✅ Worker ping: OK"
else
  say "❌ Worker ping: FAILED"
  echo "Run 'wrangler tail ops-02luka' for logs"
  exit 1
fi

# Check if health works
if echo "$WHEALTH" | grep -q 'summary'; then
  say "✅ Worker health: OK"
else
  say "❌ Worker health: FAILED"
fi

echo ""
echo "=== Phase 9.0 Ops UI Status ==="
echo "Bridge:  http://127.0.0.1:8788"
echo "Tunnel:  $TUN_URL"
echo "Worker:  $WURL"
echo ""
echo "✅ Phase 9.0 Ops UI is now live!"
echo "Open: $WURL"
