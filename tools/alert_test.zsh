#!/usr/bin/env zsh
set -euo pipefail

# --- Alert Test Utility for Phase 20.4 ---
# Sends sample alerts to Redis and/or Telegram for testing

REDIS_URL="${REDIS_URL:-redis://:${REDIS_PASSWORD:-gggclukaic}@${REDIS_HOST:-localhost}:6379}"
REDIS_CHANNEL="${1:-hub:alerts}"
TELEGRAM_TOKEN="${TELEGRAM_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"

# Sample test alert payload
ALERT_PAYLOAD=$(cat <<'EOF'
{
  "type": "test_alert",
  "level": "warning",
  "reason": "This is a test alert from alert:test command",
  "fired": true,
  "value": 99,
  "threshold": 10,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "source": "alert_test.zsh",
  "summary": {
    "mcp_unhealthy": 0,
    "errors": 5,
    "warnings": 12
  }
}
EOF
)

# Replace timestamp placeholder
ALERT_PAYLOAD=$(echo "$ALERT_PAYLOAD" | sed "s/\$(date -u +\"%Y-%m-%dT%H:%M:%SZ\")/$(date -u +"%Y-%m-%dT%H:%M:%SZ")/")

echo "🧪 Alert Test Utility"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# --- Test Redis ---
echo "\n📡 Testing Redis alert..."
echo "   Channel: $REDIS_CHANNEL"

if command -v redis-cli &>/dev/null; then
  echo "$ALERT_PAYLOAD" | redis-cli -u "$REDIS_URL" PUBLISH "$REDIS_CHANNEL" "$(cat -)" >/dev/null
  echo "   ✅ Alert published to Redis"
else
  echo "   ⚠️  redis-cli not found, using node..."
  node -e "
    const redis = require('redis');
    const client = redis.createClient({ url: '$REDIS_URL' });
    client.connect().then(() => {
      return client.publish('$REDIS_CHANNEL', \`$ALERT_PAYLOAD\`);
    }).then(() => {
      console.log('   ✅ Alert published to Redis via node');
      return client.quit();
    }).catch(err => {
      console.error('   ❌ Redis error:', err.message);
      process.exit(1);
    });
  " 2>/dev/null || echo "   ❌ Failed to publish to Redis"
fi

# --- Test Telegram (if configured) ---
if [[ -n "$TELEGRAM_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
  echo "\n📱 Testing Telegram alert..."
  echo "   Chat ID: $TELEGRAM_CHAT_ID"

  TELEGRAM_MESSAGE=$(cat <<EOF
🧪 *Test Alert*

📊 *Summary*
• MCP Unhealthy: 0
• Errors: 5
• Warnings: 12

*Alert Details:*
🟡 This is a test alert from alert:test command
   Value: 99 (threshold: 10)

⏰ $(date -u +"%Y-%m-%d %H:%M UTC")
EOF
)

  RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "$(jq -n \
      --arg chat_id "$TELEGRAM_CHAT_ID" \
      --arg text "$TELEGRAM_MESSAGE" \
      '{chat_id: $chat_id, text: $text, parse_mode: "Markdown"}')")

  if echo "$RESPONSE" | jq -e '.ok' >/dev/null 2>&1; then
    echo "   ✅ Alert sent to Telegram"
  else
    echo "   ❌ Telegram error: $(echo "$RESPONSE" | jq -r '.description // "Unknown error"')"
  fi
else
  echo "\n📱 Telegram: Not configured (TELEGRAM_TOKEN or TELEGRAM_CHAT_ID missing)"
fi

echo "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Alert test complete"
