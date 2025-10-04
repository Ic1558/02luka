#!/usr/bin/env bash

# Simple 02luka Development Startup
echo "🚀 02luka Development Startup"
echo "================================"

# Kill existing services
echo "🧹 Cleaning up existing services..."
lsof -ti :4000 | xargs -r kill -9 2>/dev/null || true
lsof -ti :5173 | xargs -r kill -9 2>/dev/null || true
sleep 1

# Start API
echo "🔧 Starting API on port 4000..."
cd /workspaces/02luka-repo/boss-api
export HOST=127.0.0.1
export PORT=4000
nohup node server.cjs > /tmp/api.log 2>&1 &
API_PID=$!
echo "API started (PID: $API_PID)"

# Start UI
echo "🎨 Starting UI on port 5173..."
cd /workspaces/02luka-repo/boss-ui
nohup python3 -m http.server 5173 > /tmp/ui.log 2>&1 &
UI_PID=$!
echo "UI started (PID: $UI_PID)"

# Wait
echo "⏳ Waiting for services to initialize..."
sleep 3

# Health checks
echo "🔍 Running health checks..."

# API health
if curl -fsS "http://127.0.0.1:4000/api/capabilities" >/dev/null 2>&1; then
  echo "✅ API: Online"
else
  echo "❌ API: Failed to respond"
  echo "API logs:"
  tail -5 /tmp/api.log
  exit 1
fi

# UI health
if curl -fsS "http://localhost:5173/luka.html" >/dev/null 2>&1; then
  echo "✅ UI: Online"
else
  echo "⚠️  UI: Responding but luka.html not found"
fi

# Run smoke tests
echo "🧪 Running smoke tests..."
cd /workspaces/02luka-repo
if bash run/smoke_api_ui.sh; then
  echo "✅ Smoke tests: PASSED"
else
  echo "⚠️  Smoke tests: Some failures (check logs)"
fi

# Summary
echo ""
echo "📊 Service Summary"
echo "=================="
echo "API:  http://127.0.0.1:4000"
echo "UI:   http://localhost:5173/luka.html"
echo "Logs: /tmp/api.log, /tmp/ui.log"
echo ""
echo "🎯 Ready for development!"







