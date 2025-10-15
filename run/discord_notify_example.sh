#!/usr/bin/env bash
# Discord Notification Examples
# Demonstrates all notification patterns for 02LUKA Discord integration

set -euo pipefail

API_URL="http://127.0.0.1:4000/api/discord/notify"

# Colors for terminal output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=== Discord Notification Examples ==="
echo ""

# Check if webhook is configured
if [ -z "${DISCORD_WEBHOOK_DEFAULT:-}" ]; then
  echo -e "${YELLOW}⚠️  DISCORD_WEBHOOK_DEFAULT not set${NC}"
  echo "Set it with: export DISCORD_WEBHOOK_DEFAULT='https://discord.com/api/webhooks/...'"
  echo ""
  echo "Continuing with examples (will fail gracefully)..."
  echo ""
fi

# Helper function to send notification
send_notification() {
  local level="$1"
  local content="$2"
  local channel="${3:-default}"
  
  echo -e "${BLUE}Sending:${NC} [$level] $content (channel: $channel)"
  
  response=$(curl -s -w "\n%{http_code}" -X POST "$API_URL" \
    -H "Content-Type: application/json" \
    -d "{\"content\":\"$content\",\"level\":\"$level\",\"channel\":\"$channel\"}" 2>/dev/null)
  
  http_code=$(echo "$response" | tail -n 1)
  body=$(echo "$response" | head -n -1)
  
  if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}✅ Success ($http_code)${NC}"
  elif [ "$http_code" = "503" ]; then
    echo -e "${YELLOW}⚠️  Webhook not configured ($http_code)${NC}"
  else
    echo -e "${RED}❌ Failed ($http_code): $body${NC}"
  fi
  
  echo ""
  sleep 1 # Avoid rate limits
}

# Example 1: Info notification (default)
echo "--- Example 1: Info Notification ---"
send_notification "info" "System startup complete"

# Example 2: Warning notification
echo "--- Example 2: Warning Notification ---"
send_notification "warn" "High memory usage detected (85%)"

# Example 3: Error notification
echo "--- Example 3: Error Notification ---"
send_notification "error" "Database connection failed"

# Example 4: Custom channel (requires DISCORD_WEBHOOK_MAP)
echo "--- Example 4: Custom Channel ---"
send_notification "info" "Deployment started" "ops"

# Example 5: Multi-line content
echo "--- Example 5: Multi-line Content ---"
send_notification "info" "Build Report:\n- Tests: 42 passed\n- Coverage: 87%\n- Duration: 3m 12s"

# Example 6: Code block formatting
echo "--- Example 6: Code Block ---"
send_notification "error" "\`\`\`\nError: Connection timeout\n  at TCPSocket.connect (net.js:123)\n  at Server.listen (http.js:456)\n\`\`\`"

# Example 7: With URL
echo "--- Example 7: With Hyperlink ---"
send_notification "info" "Build completed! View logs: https://example.com/logs/12345"

# Example 8: Mention (safe - won't ping @everyone due to allowed_mentions config)
echo "--- Example 8: Safe Mention Test ---"
send_notification "info" "Deployment ready for @everyone review" "ops"

echo "=== Examples Complete ==="
echo ""
echo "💡 Tips:"
echo "  - Messages support Discord markdown (bold, italic, code)"
echo "  - Rate limit: 5 requests per 2 seconds per webhook"
echo "  - Use different channels for different notification types"
echo "  - Webhook URL format: https://discord.com/api/webhooks/{id}/{token}"
echo ""
echo "📚 See docs/integrations/discord.md for full documentation"
