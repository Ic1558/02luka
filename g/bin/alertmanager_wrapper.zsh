#!/usr/bin/env zsh
# Wrapper script for Alertmanager that loads secrets from .env/alerts
set -euo pipefail

LUKA_HOME="${LUKA_HOME:-$HOME/LocalProjects/02luka_local_g/g}"
# Use stable locations outside Google Drive to avoid sync issues
STABLE_DIR="$HOME/.config/02luka/alertmanager"
ENV_FILE="$HOME/.config/02luka/secrets/telegram.env"
TEMPLATE="$STABLE_DIR/alertmanager.yml"
RUNTIME_CONFIG="$STABLE_DIR/alertmanager_runtime.yml"
DATA_DIR="$HOME/.local/share/02luka/alertmanager"

# Load secrets if file exists
if [[ -f "$ENV_FILE" ]]; then
  source "$ENV_FILE"
fi

# Set defaults - use Trade Alert bot for trading
TELEGRAM_BOT_TOKEN="${TRADE_BOT_TOKEN:-7907375805:AAHRJqOYGuZUueBUdGpSklgOztao0LObPjY}"
TELEGRAM_CHAT_ID="${CHAT_ID:-6351780525}"

# Create directories
mkdir -p "$STABLE_DIR" "$DATA_DIR"

# Extract template from git if not exists
if [[ ! -f "$TEMPLATE" ]]; then
  git -C "$LUKA_HOME" show HEAD:config/alertmanager/alertmanager.yml > "$TEMPLATE" 2>/dev/null || true
fi

# Expand template with actual values
sed -e "s|__TELEGRAM_BOT_TOKEN__|${TELEGRAM_BOT_TOKEN}|g" \
    -e "s|__TELEGRAM_CHAT_ID__|${TELEGRAM_CHAT_ID}|g" \
    "$TEMPLATE" > "$RUNTIME_CONFIG"

# Start Alertmanager with expanded config
exec "$HOME/bin/alertmanager" \
  --config.file="$RUNTIME_CONFIG" \
  --storage.path="$DATA_DIR" \
  --web.listen-address=127.0.0.1:9093 \
  --data.retention=120h
