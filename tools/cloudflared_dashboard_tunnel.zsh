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
if ! envsubst < "$CONFIG" > "$TEMP_CONFIG" 2>/dev/null; then
  echo "[cloudflared-dashboard] WARNING: envsubst failed, using original config" >&2
  cp "$CONFIG" "$TEMP_CONFIG"
fi

# Verify RELAY_KEY is set (for debugging)
if [[ -z "${RELAY_KEY:-}" ]]; then
  echo "[cloudflared-dashboard] ERROR: RELAY_KEY is not set in environment!" >&2
  echo "[cloudflared-dashboard] Check that .env.local contains RELAY_KEY=" >&2
fi

echo "[cloudflared-dashboard] starting tunnel with $CONFIG (expanded env vars)"
echo "[cloudflared-dashboard] RELAY_KEY length: ${#RELAY_KEY:-0}" >>"$LOG_DIR/dashboard.tunnel.log" 2>&1
exec cloudflared tunnel --config "$TEMP_CONFIG" run >>"$LOG_DIR/dashboard.tunnel.log" 2>&1
