#!/usr/bin/env zsh
set -euo pipefail
"$HOME/02luka/tools/smoke_dashboard.zsh"
"$HOME/02luka/tools/smoke_dashboard_prom.zsh"
echo "boss-api: HEALTH OK"
