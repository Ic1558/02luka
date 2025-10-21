#!/usr/bin/env bash
set -euo pipefail

echo "=========================================="
echo "Restarting with Fixed Configuration"
echo "=========================================="

cd "$HOME/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka/02luka-repo"

echo ">>> Stopping containers..."
docker compose down

echo ""
echo ">>> Starting containers..."
docker compose up -d

echo ""
echo ">>> Waiting for Redis to be healthy..."
sleep 5

# Check Redis
echo ">>> Checking Redis..."
if docker compose exec redis redis-cli ping | grep -q PONG; then
  echo "✅ Redis is UP"
else
  echo "⚠️ Redis not responding"
  docker compose logs redis --tail=20
  exit 1
fi

echo ""
echo ">>> Waiting for bridge to start..."
sleep 3

# Load .env
set -a
source .env
set +a

echo ">>> Checking bridge..."
for i in {1..10}; do
  if curl -s -H "x-auth-token: $BRIDGE_TOKEN" http://127.0.0.1:8788/ping 2>/dev/null | grep -q '"ok":true'; then
    echo "✅ Bridge is UP and responding!"
    echo ""
    echo "=========================================="
    echo "SUCCESS! Phase 9.0 Ready"
    echo "=========================================="
    echo ""
    echo "Next steps:"
    echo "  1. Run bootstrap: ./WO-OPS-BOOTSTRAP.sh"
    echo "  2. Deploy worker: ./WO-OPS-PUBLISH-WORKER.sh --ephemeral"
    echo "  3. Verify: make verify-ops"
    echo ""
    exit 0
  fi
  echo "Attempt $i/10..."
  sleep 2
done

echo "⚠️ Bridge still not responding after 10 attempts"
echo "Checking logs..."
docker compose logs bridge --tail=50
