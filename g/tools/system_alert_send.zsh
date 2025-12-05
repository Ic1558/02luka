#!/usr/bin/env zsh
# Unified system alert sender
# Usage: system_alert_send.zsh LEVEL SOURCE "message text"
# Example: system_alert_send.zsh GUARD luka-guard "Guard health check FAILED"

set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

LEVEL="${1:-INFO}"
SOURCE="${2:-system}"
shift 2 || true
MSG="${*:-no message}"

# 1) Load env
ENV_FILE="$HOME/02luka/.env.local"
if [[ -f "$ENV_FILE" ]]; then
  set -o allexport
  source "$ENV_FILE"
  set +o allexport
fi

# 2) Resolve token/chat with fallback
TOKEN="${TELEGRAM_SYSTEM_ALERT_BOT_TOKEN:-${TELEGRAM_BOT_TOKEN_GPT_ALERTS:-${TELEGRAM_GUARD_BOT_TOKEN:-}}}"
CHAT_ID="${TELEGRAM_SYSTEM_ALERT_CHAT_ID:-${TELEGRAM_BOT_CHAT_ID_GPT_ALERTS:-${TELEGRAM_GUARD_CHAT_ID:-}}}"

if [[ -z "${TOKEN:-}" || -z "${CHAT_ID:-}" ]]; then
  echo "[system_alert_send] missing TELEGRAM_SYSTEM_ALERT_* or fallback token/chat_id" >&2
  exit 1
fi

TEXT="[$LEVEL][$SOURCE] ${MSG}"

curl -sS -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
  -d "chat_id=${CHAT_ID}" \
  -d "text=${TEXT}" \
  -d "parse_mode=Markdown" >/dev/null

echo "[system_alert_send] sent: ${TEXT}"
