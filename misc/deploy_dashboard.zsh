#!/usr/bin/env zsh
set -euo pipefail
source "$HOME/.config/02luka/secrets/grafana.env" 2>/dev/null || true
echo "🔧 Checking Grafana + ops endpoint..."
curl -sSf https://ops.theedges.work/ping >/dev/null || { echo "❌ ops endpoint not ready"; exit 1; }
curl -sSf http://localhost:3000/login >/dev/null || { echo "❌ grafana not reachable"; exit 1; }
echo "✅ Dashboard online"
echo "http://localhost:3000"
echo "https://ops.theedges.work"
