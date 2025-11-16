#!/usr/bin/env zsh
set -euo pipefail

echo "🏥 Health Server Status Check"
echo "=============================="

# Check health_server endpoint
if curl -sf -H "Host: localhost:4000" http://localhost:4000/ping >/dev/null 2>&1; then
  echo "✅ health_server responding on :4000"
else
  echo "❌ health_server not responding"
fi

echo ""
echo "📊 Docker Services:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" --filter "name=02luka" 2>/dev/null || docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
