#!/usr/bin/env zsh
set -euo pipefail

# ตั้ง PATH ให้มี homebrew ด้วย (ทั้ง /opt/homebrew และ /usr/local)
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

# Load RELAY_KEY from .env.local
ENV_LOCAL="$HOME/02luka/.env.local"
if [[ -f "$ENV_LOCAL" ]]; then
  set -a
  source "$ENV_LOCAL"
  set +a
fi

LOG_DIR="$HOME/02luka/logs/cloudflared"
mkdir -p "$LOG_DIR"

CONFIG="$HOME/.cloudflared/dashboard.yml"

if [[ ! -f "$CONFIG" ]]; then
  echo "[cloudflared-dashboard] Config not found: $CONFIG" >&2
  exit 1
fi

# Expand environment variables in config (for ${RELAY_KEY} etc.)
TEMP_CONFIG=$(mktemp)
envsubst < "$CONFIG" > "$TEMP_CONFIG"

echo "[cloudflared-dashboard] starting tunnel with $CONFIG (expanded env vars)"
exec cloudflared tunnel --config "$TEMP_CONFIG" run >>"$LOG_DIR/dashboard.tunnel.log" 2>&1
