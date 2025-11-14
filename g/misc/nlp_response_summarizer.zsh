#!/usr/bin/env zsh
# NLP Response Summarizer - Formats command output and sends to Telegram
set -euo pipefail

# Load Telegram secrets (bot token, chat ID)
if [[ -f "$HOME/.config/02luka/secrets/telegram.env" ]]; then
  source "$HOME/.config/02luka/secrets/telegram.env"
fi

: "${TELEGRAM_BOT_TOKEN:=7683891739:AAFnHw3zkXBZecmzIty4iYTv8e_QxZYgAmk}"
: "${TELEGRAM_CHAT_ID:=-1002449985799}"

# Parse input (intent, exit_code, output from stdin)
INTENT="${1:-unknown}"
EXIT_CODE="${2:-0}"
OUTPUT=$(cat)

# Format status emoji
if [[ "$EXIT_CODE" -eq 0 ]]; then
  STATUS="✅"
  RESULT="Success"
else
  STATUS="⚠️"
  RESULT="Failed (exit $EXIT_CODE)"
fi

# Get last 3 lines of output
LAST_LINES=$(echo "$OUTPUT" | tail -3 | sed 's/^/  /')

# Format message
MSG=$(cat <<EOF
🤖 Andy Response

Intent: \`$INTENT\`
Status: $STATUS $RESULT

Output:
\`\`\`
$LAST_LINES
\`\`\`
EOF
)

# Send to Telegram
curl -sS -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  -H "Content-Type: application/json" \
  -d "{\"chat_id\":\"${TELEGRAM_CHAT_ID}\",\"text\":$(echo "$MSG" | jq -Rs .),\"parse_mode\":\"Markdown\"}" \
  >/dev/null 2>&1 || true

# Also log locally
echo "[$(date +'%Y-%m-%d %H:%M:%S')] $STATUS $INTENT (exit=$EXIT_CODE)" >> "$HOME/02luka/logs/nlp_responses.log"
