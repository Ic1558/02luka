#!/usr/bin/env zsh
set -euo pipefail
BASE="${LUKA_HOME:-$HOME/02luka}"   # prefer LUKA_HOME, fallback to old path
"${BASE}/tools/smoke_dashboard.zsh"
"${BASE}/tools/smoke_dashboard_prom.zsh"
echo "boss-api: HEALTH OK"
