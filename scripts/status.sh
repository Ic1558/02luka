#!/usr/bin/env bash
set -euo pipefail
cd "$HOME/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka/02luka-repo"

echo "🔍 02LUKA Quick Status"
echo ""

# Redis
echo -n "Redis: "
if command -v redis-cli &>/dev/null; then
  if redis-cli -h 127.0.0.1 -p 6379 -a changeme-02luka ping 2>/dev/null | grep -q PONG; then
    echo "✅ PONG"
  else
    echo "❌ No response"
  fi
else
  nc -z 127.0.0.1 6379 2>/dev/null && echo "✅ Port open (no cli)" || echo "❌ Closed"
fi

# API
echo -n "API (4000): "
curl -fsS http://127.0.0.1:4000/healthz >/dev/null 2>&1 && echo "✅ Responding" || echo "❌ Down"

# MCP
echo -n "MCP (3003): "
curl -fsS http://127.0.0.1:3003 >/dev/null 2>&1 && echo "✅ Responding" || echo "⚠️  Down (stub expected)"

# Health Proxy
echo -n "Health Proxy (3002): "
curl -fsS http://127.0.0.1:3002 >/dev/null 2>&1 && echo "✅ Responding" || echo "⚠️  Down (stub expected)"

# LaunchAgents
LA=$(launchctl list 2>/dev/null | grep -c "com\.02luka\." || true)
echo ""
echo "LaunchAgents: ${LA} loaded"

# Last heartbeat
LAST=$(ls -t g/reports/ops_atomic/heartbeat_* 2>/dev/null | head -1 || echo "")
if [[ -n "$LAST" ]]; then
  echo "Last heartbeat: $(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$LAST" 2>/dev/null || date -r $(stat -f %m "$LAST") '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "unknown")"
else
  echo "Last heartbeat: (none found)"
fi

# Health age
if [[ -f g/reports/system_health_stamp.txt ]]; then
  stamp=$(cat g/reports/system_health_stamp.txt)
  echo "Health stamp: $stamp"
else
  echo "Health stamp: (not found)"
fi

echo ""
echo "✅ Quick status complete"
