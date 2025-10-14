#!/usr/bin/env bash
set -euo pipefail

# 02luka Development Startup Script
# Fixes: port conflicts, path issues, and service management

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
API_PORT=4000
UI_PORT=5173

echo "🚀 02luka Development Startup"
echo "================================"

# 1. Kill existing services (safe)
echo "🧹 Cleaning up existing services..."
lsof -ti :$API_PORT | xargs -r kill -9 2>/dev/null || true
lsof -ti :$UI_PORT | xargs -r kill -9 2>/dev/null || true
sleep 1

# 2. Start API (always from root)
echo "🔧 Starting API on port $API_PORT..."
cd "$ROOT"
export HOST=127.0.0.1
export PORT=$API_PORT
nohup node boss-api/server.cjs > /tmp/api.log 2>&1 &
API_PID=$!
echo "API started (PID: $API_PID)"

# 3. Start UI (check if boss-ui exists)
if [ -d "$ROOT/boss-ui" ]; then
  echo "🎨 Starting UI on port $UI_PORT..."
  cd "$ROOT/boss-ui"
  nohup python3 -m http.server $UI_PORT > /tmp/ui.log 2>&1 &
  UI_PID=$!
  echo "UI started (PID: $UI_PID)"
  cd "$ROOT"
else
  echo "⚠️  WARN: boss-ui/ not found, skipping UI"
  UI_PID=""
fi

# 4. Wait for services to start
echo "⏳ Waiting for services to initialize..."
sleep 3

# 5. Health checks
echo "🔍 Running health checks..."

# API health
if curl -fsS "http://127.0.0.1:$API_PORT/api/capabilities" >/dev/null 2>&1; then
  echo "✅ API: Online"
else
  echo "❌ API: Failed to respond"
  echo "API logs:"
  tail -5 /tmp/api.log
  exit 1
fi

# UI health (if started)
if [ -n "$UI_PID" ]; then
  if curl -fsS "http://localhost:$UI_PORT/luka.html" >/dev/null 2>&1; then
    echo "✅ UI: Online"
  else
    echo "⚠️  UI: Responding but luka.html not found"
  fi
fi

# 6. Run smoke tests
echo "🧪 Running smoke tests..."
if bash run/smoke_api_ui.sh; then
  echo "✅ Smoke tests: PASSED"
else
  echo "⚠️  Smoke tests: Some failures (check logs)"
fi

# 7. Summary
echo ""
echo "📊 Service Summary"
echo "=================="
echo "API:  http://127.0.0.1:$API_PORT"
if [ -n "$UI_PID" ]; then
  echo "UI:   http://localhost:$UI_PORT/luka.html"
fi
echo "Logs: /tmp/api.log, /tmp/ui.log"
echo ""
echo "🎯 Ready for development!"
