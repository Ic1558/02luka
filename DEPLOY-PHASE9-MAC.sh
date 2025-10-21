#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Phase 9.0 Deployment - Mac Edition
# Auto-generated for Mac Terminal execution
# ==============================================================================

REPO_DIR="$HOME/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka/02luka-repo"

cd "$REPO_DIR" || {
  echo "ERROR: Cannot cd to $REPO_DIR"
  exit 1
}

echo "=========================================="
echo "Phase 9.0 Deployment Starting..."
echo "=========================================="
echo ""

# Load environment
echo ">>> Loading .env..."
set -a
source .env
set +a

echo "REPO_HOST_PATH=$REPO_HOST_PATH"
echo "BRIDGE_TOKEN=${BRIDGE_TOKEN:0:16}..." # show first 16 chars only
echo ""

# Step 2: Start Docker Stack
echo "=========================================="
echo "Step 2: Starting Docker Stack"
echo "=========================================="
docker compose up -d
sleep 3

echo ""
echo ">>> Checking bridge health..."
if curl -s -H "x-auth-token: $BRIDGE_TOKEN" http://127.0.0.1:8788/ping | grep -q '"ok":true'; then
  echo "✅ Bridge is UP and responding"
else
  echo "⚠️  Bridge not responding, checking logs..."
  docker compose logs bridge --tail=50
  exit 1
fi
echo ""

# Step 3: Bootstrap
echo "=========================================="
echo "Step 3: Running Bootstrap Tests"
echo "=========================================="
./WO-OPS-BOOTSTRAP.sh
echo ""

# Step 4: Worker Deployment (optional)
echo "=========================================="
echo "Step 4: Worker Deployment (Optional)"
echo "=========================================="
echo "Checking for cloudflared and wrangler..."

if command -v cloudflared &> /dev/null && command -v wrangler &> /dev/null; then
  echo "✅ Found cloudflared and wrangler"
  echo ""
  echo "Deploy worker now? (y/n)"
  read -r DEPLOY_WORKER
  
  if [[ "$DEPLOY_WORKER" =~ ^[Yy]$ ]]; then
    ./WO-OPS-PUBLISH-WORKER.sh --ephemeral
  else
    echo "Skipping worker deployment. You can run it later with:"
    echo "./WO-OPS-PUBLISH-WORKER.sh --ephemeral"
  fi
else
  echo "⚠️  cloudflared or wrangler not found"
  echo "Worker deployment skipped. Install them to deploy:"
  echo "  brew install cloudflared"
  echo "  npm install -g wrangler"
  echo ""
  echo "You can deploy the worker later with:"
  echo "./WO-OPS-PUBLISH-WORKER.sh --ephemeral"
fi
echo ""

# Step 5: Local Verification
echo "=========================================="
echo "Step 5: Local Verification"
echo "=========================================="

if command -v make &> /dev/null; then
  echo "Running verification..."
  make verify-ops || echo "⚠️  Verification had issues (check output above)"
  echo ""
  echo "Showing verification status..."
  make show-verify || echo "⚠️  Could not show verification"
else
  echo "⚠️  'make' not found, skipping verification"
  echo "You can verify manually later with:"
  echo "  make verify-ops"
  echo "  make show-verify"
fi
echo ""

# Summary
echo "=========================================="
echo "Phase 9.0 Deployment Complete!"
echo "=========================================="
echo ""
echo "✅ Docker stack is running"
echo "✅ Bridge is accessible at http://127.0.0.1:8788"
echo ""
echo "Quick status check:"
echo "  docker compose ps"
echo ""
echo "Bridge health:"
echo "  curl -s -H 'x-auth-token: $BRIDGE_TOKEN' http://127.0.0.1:8788/ops-health | jq '.summary'"
echo ""
echo "View logs:"
echo "  docker compose logs -f bridge"
echo ""

if command -v wrangler &> /dev/null; then
  echo "To deploy worker later:"
  echo "  ./WO-OPS-PUBLISH-WORKER.sh --ephemeral"
  echo ""
fi

echo "For autonomy features:"
echo "  make auto-advice   # supervised mode"
echo "  make auto-auto     # full autonomy (after burn-in)"
echo ""
echo "=========================================="
