#!/usr/bin/env bash

# Final 02luka Development Startup Script
echo "🚀 02luka Development Startup"
echo "================================"

# Check if services are already running
API_RUNNING=false
UI_RUNNING=false

if curl -fsS "http://127.0.0.1:4000/api/capabilities" >/dev/null 2>&1; then
  echo "✅ API already running on port 4000"
  API_RUNNING=true
fi

if curl -fsS "http://localhost:5173/luka.html" >/dev/null 2>&1; then
  echo "✅ UI already running on port 5173"
  UI_RUNNING=true
fi

# Start API if not running
if [ "$API_RUNNING" = false ]; then
  echo "🔧 Starting API on port 4000..."
  cd /workspaces/02luka-repo/boss-api
  export HOST=127.0.0.1
  export PORT=4000
  nohup node server.cjs > /tmp/api.log 2>&1 &
  API_PID=$!
  echo "API started (PID: $API_PID)"
  sleep 2
fi

# Start UI if not running
if [ "$UI_RUNNING" = false ]; then
  echo "🎨 Starting UI on port 5173..."
  cd /workspaces/02luka-repo/boss-ui
  nohup python3 -m http.server 5173 > /tmp/ui.log 2>&1 &
  UI_PID=$!
  echo "UI started (PID: $UI_PID)"
  sleep 2
fi

# Health checks
echo "🔍 Running health checks..."

# API health
if curl -fsS "http://127.0.0.1:4000/api/capabilities" >/dev/null 2>&1; then
  echo "✅ API: Online"
  curl -s http://127.0.0.1:4000/api/capabilities | jq '.features'
else
  echo "❌ API: Failed to respond"
  echo "API logs:"
  tail -5 /tmp/api.log
fi

# UI health
if curl -fsS "http://localhost:5173/luka.html" >/dev/null 2>&1; then
  echo "✅ UI: Online"
else
  echo "⚠️  UI: Responding but luka.html not found"
fi

# Test chat endpoint
echo "🧪 Testing chat endpoint..."
CHAT_RESPONSE=$(curl -s -X POST http://127.0.0.1:4000/api/chat -H 'Content-Type: application/json' -d '{"input":"test message"}' | jq -r '.summary')
echo "Chat response: $CHAT_RESPONSE"

# Run smoke tests
echo "🧪 Running smoke tests..."
cd /workspaces/02luka-repo
bash run/smoke_api_ui.sh || echo "⚠️  Smoke tests: Some failures (check logs)"

# Summary
echo ""
echo "📊 Service Summary"
echo "=================="
echo "API:  http://127.0.0.1:4000"
echo "UI:   http://localhost:5173/luka.html"
echo "Logs: /tmp/api.log, /tmp/ui.log"
echo ""
echo "🎯 Ready for development!"







