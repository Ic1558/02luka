#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/../scripts/repo_root_resolver.sh"

API_BASE_URL="${API_BASE_URL:-http://127.0.0.1:4000}"
ENDPOINT="$API_BASE_URL/api/discord/notify"

if [ -z "${DISCORD_WEBHOOK_DEFAULT:-}" ] && [ -z "${DISCORD_WEBHOOK_MAP:-}" ]; then
  echo "Neither DISCORD_WEBHOOK_DEFAULT nor DISCORD_WEBHOOK_MAP is set."
  echo "Export a webhook URL before running this script."
  exit 1
fi

alerts_channel_available=false
if [ -n "${DISCORD_WEBHOOK_MAP:-}" ]; then
  if python - "$DISCORD_WEBHOOK_MAP" <<'PY'; then
import json
import sys
try:
    data = json.loads(sys.argv[1])
except Exception:
    sys.exit(1)
if isinstance(data, dict) and 'alerts' in data:
    sys.exit(0)
sys.exit(1)
PY
  then
    alerts_channel_available=true
  fi
fi

send_notification() {
  local message="$1"
  local level="$2"
  local channel="$3"

  echo ""
  echo "→ Sending level=$level channel=$channel"

  local payload
  payload=$(python - "$message" "$level" "$channel" <<'PY'
import json
import sys
content, level, channel = sys.argv[1:4]
print(json.dumps({
    "content": content,
    "level": level,
    "channel": channel
}))
PY
)

  curl -sS -X POST "$ENDPOINT" \
    -H "Content-Type: application/json" \
    -d "$payload"
  echo ""
}

echo "Posting Discord notification samples via $ENDPOINT"

send_notification "02LUKA webhook relay test (info)" "info" "default"

if [ "$alerts_channel_available" = true ]; then
  send_notification "02LUKA webhook relay test (warn)" "warn" "alerts"
else
  send_notification "02LUKA webhook relay test (warn)" "warn" "default"
fi

send_notification "02LUKA webhook relay test (error)" "error" "default"

echo ""
echo "Done. Check your Discord channel for the test messages."
