#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Quick Fix: Install Missing Dependencies
# ==============================================================================

echo "=========================================="
echo "Installing Node.js Dependencies"
echo "=========================================="

cd "$HOME/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka/02luka-repo"

# Install npm dependencies
echo ">>> Running npm install..."
npm install

echo ""
echo "✅ Dependencies installed!"
echo ""
echo ">>> Restarting Docker stack..."
docker compose down
docker compose up -d

echo ""
echo "Waiting for services to start..."
sleep 5

echo ""
echo ">>> Loading .env..."
set -a
source .env
set +a

echo ">>> Checking bridge health..."
if curl -s -H "x-auth-token: $BRIDGE_TOKEN" http://127.0.0.1:8788/ping | grep -q '"ok":true'; then
  echo "✅ Bridge is UP and responding!"
  echo ""
  echo "=========================================="
  echo "Fix Complete! Ready to Continue"
  echo "=========================================="
  echo ""
  echo "Run bootstrap now:"
  echo "  ./WO-OPS-BOOTSTRAP.sh"
else
  echo "⚠️ Bridge still not responding"
  echo "Checking logs..."
  docker compose logs bridge --tail=50
fi
