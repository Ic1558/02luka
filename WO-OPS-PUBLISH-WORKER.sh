#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 02LUKA • Worker Publish Script
# One-shot: tunnel + deploy worker + verify end-to-end
# Usage: ./WO-OPS-PUBLISH-WORKER.sh [--ephemeral] [--named-tunnel]
# ==============================================================================

ROOT="$(pwd)"
WORKER_DIR="$HOME/ops-02luka-worker"
EPHEMERAL=1
NAMED_TUNNEL=""

for a in "$@"; do
  case "$a" in
    --ephemeral)     EPHEMERAL=1 ;;
    --named-tunnel) NAMED_TUNNEL="ops-bridge"; EPHEMERAL=0 ;;
    *) echo "Unknown arg: $a" >&2; exit 2 ;;
  esac
done

say() { printf '%s %s\n' ">>> " "$*"; }
fail() { echo "ERROR: $*" >&2; exit 1; }

# ------------------------------------------------------------------------------
# Preflight
# ------------------------------------------------------------------------------
say "Preflight checks"
command -v cloudflared >/dev/null || fail "cloudflared not found"
command -v wrangler >/dev/null || fail "wrangler not found"
command -v jq >/dev/null || fail "jq not found"
test -f .env || fail ".env not found"
source .env

BRIDGE_TOKEN="${BRIDGE_TOKEN:-}"
test -n "$BRIDGE_TOKEN" || fail "BRIDGE_TOKEN not set in .env"

# Check if bridge is running
if ! curl -sf -H "x-auth-token: $BRIDGE_TOKEN" http://127.0.0.1:8788/ping >/dev/null 2>&1; then
  say "Bridge not running on 127.0.0.1:8788. Starting stack..."
  docker compose up -d || fail "Failed to start Docker stack"
  
  # Wait for bridge
  say "Waiting for bridge to come up..."
  for i in {1..30}; do
    if curl -sf -H "x-auth-token: $BRIDGE_TOKEN" http://127.0.0.1:8788/ping >/dev/null 2>&1; then
      say "Bridge is up"
      break
    fi
    sleep 1
    [[ $i -eq 30 ]] && fail "Bridge did not come up"
  done
fi

# ------------------------------------------------------------------------------
# Tunnel Setup
# ------------------------------------------------------------------------------
if [[ "$EPHEMERAL" -eq 1 ]]; then
  say "Starting ephemeral tunnel (trycloudflare.com)"
  # Start tunnel in background and capture URL
  TUNNEL_LOG="/tmp/cloudflared-tunnel.log"
  cloudflared tunnel --url http://127.0.0.1:8788 > "$TUNNEL_LOG" 2>&1 &
  TUNNEL_PID=$!
  
  # Wait for tunnel URL
  say "Waiting for tunnel URL..."
  for i in {1..30}; do
    if grep -q "https://.*\.trycloudflare\.com" "$TUNNEL_LOG" 2>/dev/null; then
      BRIDGE_URL=$(grep -o "https://[^[:space:]]*\.trycloudflare\.com" "$TUNNEL_LOG" | head -1)
      say "Tunnel URL: $BRIDGE_URL"
      break
    fi
    sleep 1
    [[ $i -eq 30 ]] && fail "Tunnel did not start"
  done
else
  say "Setting up named tunnel: $NAMED_TUNNEL"
  cloudflared tunnel create "$NAMED_TUNNEL" || fail "Failed to create tunnel"
  BRIDGE_URL="https://bridge.theedges.work"
  say "Named tunnel URL: $BRIDGE_URL"
fi

# ------------------------------------------------------------------------------
# Worker Setup
# ------------------------------------------------------------------------------
say "Setting up Worker directory"
mkdir -p "$WORKER_DIR"

# Create minimal wrangler.toml
cat > "$WORKER_DIR/wrangler.toml" <<TOML
name = "ops-02luka"
main = "ops-worker.js"
compatibility_date = "2024-10-01"

[vars]
OPS_DOMAIN = "https://ops-02luka.\${CLOUDFLARE_ACCOUNT_ID}.workers.dev"
TOML

# Create minimal ops-worker.js if not exists
if [[ ! -f "$WORKER_DIR/ops-worker.js" ]]; then
  cat > "$WORKER_DIR/ops-worker.js" <<'JS'
export default {
  async fetch(req, env) {
    const url = new URL(req.url);
    
    // Proxy API requests to bridge
    if (url.pathname.startsWith('/api/')) {
      const bridgeUrl = env.BRIDGE_URL + url.pathname + (url.search || '');
      const headers = {
        'x-auth-token': env.BRIDGE_TOKEN,
        'content-type': req.headers.get('content-type') || 'application/json'
      };
      
      try {
        const response = await fetch(bridgeUrl, {
          method: req.method,
          headers,
          body: req.method !== 'GET' ? await req.text() : undefined
        });
        
        return new Response(await response.text(), {
          status: response.status,
          headers: { 'content-type': 'application/json' }
        });
      } catch (e) {
        return new Response(JSON.stringify({ok: false, error: 'bridge_error', detail: String(e)}), {
          status: 502,
          headers: { 'content-type': 'application/json' }
        });
      }
    }
    
    // Simple UI for root
    if (url.pathname === '/') {
      return new Response(`
<!doctype html>
<meta charset="utf-8">
<title>02LUKA Ops UI</title>
<style>
body { font: 14px system-ui; margin: 24px; }
.card { border: 1px solid #ddd; border-radius: 8px; padding: 16px; margin: 16px 0; }
.status { display: inline-block; padding: 4px 8px; border-radius: 4px; }
.ok { background: #d4edda; color: #155724; }
.error { background: #f8d7da; color: #721c24; }
</style>
<h1>02LUKA Ops UI</h1>
<div class="card">
  <h3>System Status</h3>
  <div id="status">Loading...</div>
</div>
<div class="card">
  <h3>API Endpoints</h3>
  <ul>
    <li><a href="/api/ping">/api/ping</a> - System ping</li>
    <li><a href="/api/health">/api/health</a> - Health metrics</li>
    <li><a href="/api/verify">/api/verify</a> - Verification status</li>
    <li><a href="/api/auto/status">/api/auto/status</a> - Autonomy status</li>
  </ul>
</div>
<script>
async function loadStatus() {
  try {
    const r = await fetch('/api/ping');
    const j = await r.json();
    document.getElementById('status').innerHTML = 
      '<span class="status ok">✅ System Online</span>';
  } catch (e) {
    document.getElementById('status').innerHTML = 
      '<span class="status error">❌ System Offline</span>';
  }
}
loadStatus();
</script>
`, {
        headers: { 'content-type': 'text/html; charset=utf-8' }
      });
    }
    
    return new Response('Not found', { status: 404 });
  }
};
JS
fi

# ------------------------------------------------------------------------------
# Deploy Worker
# ------------------------------------------------------------------------------
say "Deploying Worker"
cd "$WORKER_DIR"

# Set secrets
echo "$BRIDGE_URL" | wrangler secret put BRIDGE_URL
echo "$BRIDGE_TOKEN" | wrangler secret put BRIDGE_TOKEN

# Deploy
wrangler deploy || fail "Worker deployment failed"

# Get the deployed URL
WORKER_URL=$(wrangler whoami 2>/dev/null | grep -o 'https://ops-02luka-[^[:space:]]*\.workers\.dev' || echo "https://ops-02luka.workers.dev")
say "Worker deployed at: $WORKER_URL"

# ------------------------------------------------------------------------------
# Verification
# ------------------------------------------------------------------------------
say "Running smoke tests"

# Test ping
if curl -sf "$WORKER_URL/api/ping" | jq -e '.ok' >/dev/null 2>&1; then
  say "✅ Worker ping: OK"
else
  say "❌ Worker ping: FAILED"
fi

# Test health
if curl -sf "$WORKER_URL/api/health" | jq -e '.summary' >/dev/null 2>&1; then
  say "✅ Worker health: OK"
else
  say "❌ Worker health: FAILED"
fi

# Test verify
if curl -sf "$WORKER_URL/api/verify" | jq -e '.ok' >/dev/null 2>&1; then
  say "✅ Worker verify: OK"
else
  say "❌ Worker verify: FAILED"
fi

# Test autonomy
if curl -sf "$WORKER_URL/api/auto/status" | jq -e '.ok' >/dev/null 2>&1; then
  say "✅ Worker autonomy: OK"
else
  say "❌ Worker autonomy: FAILED"
fi

# ------------------------------------------------------------------------------
# Final Output
# ------------------------------------------------------------------------------
echo
echo "======================================================================="
echo "Worker Deployment Complete"
echo "- Worker URL: $WORKER_URL"
echo "- Bridge URL: $BRIDGE_URL"
echo "- Tunnel: $([ "$EPHEMERAL" -eq 1 ] && echo "Ephemeral (trycloudflare.com)" || echo "Named ($NAMED_TUNNEL)")"
echo
echo "Quick Tests:"
echo "curl -s $WORKER_URL/api/ping | jq"
echo "curl -s $WORKER_URL/api/health | jq '.summary'"
echo "curl -s $WORKER_URL/api/verify | jq"
echo "curl -s $WORKER_URL/api/auto/status | jq"
echo
echo "Open in browser: $WORKER_URL"
echo "======================================================================="
echo

# Cleanup tunnel log
rm -f "$TUNNEL_LOG" 2>/dev/null || true
