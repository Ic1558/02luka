#!/usr/bin/env bash
# Dispatches a rich ops notification to the local Discord webhook bridge.
# Usage: scripts/discord_ops_notify.sh --status pass --summary "PASS=3 WARN=0 FAIL=0" \
#        --details "• Phase 1 — PASS" --link "https://example.com/report.md"

set -euo pipefail

# Load .env file for Discord webhook configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../boss-api/.env"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  source "$ENV_FILE"
  set +a
fi

TITLE="OPS Atomic Run"
STATUS="unknown"
SUMMARY=""
DETAILS=""
REPORT_LINK=""
CHANNEL="${REPORT_CHANNEL:-ops}"
COUNTS=""
API_URL="${DISCORD_NOTIFY_API_URL:-http://127.0.0.1:4000/api/discord/notify}"
TIMEOUT_SECONDS=${DISCORD_NOTIFY_TIMEOUT:-8}
RETRY_DELAY=${DISCORD_NOTIFY_RETRY_DELAY:-2}
MAX_ATTEMPTS=2

while [[ $# -gt 0 ]]; do
  case "$1" in
    --status)
      STATUS="$2"
      shift 2
      ;;
    --summary)
      SUMMARY="$2"
      shift 2
      ;;
    --details)
      DETAILS="$2"
      shift 2
      ;;
    --link)
      REPORT_LINK="$2"
      shift 2
      ;;
    --channel)
      CHANNEL="$2"
      shift 2
      ;;
    --title)
      TITLE="$2"
      shift 2
      ;;
    --counts)
      COUNTS="$2"
      shift 2
      ;;
    --help|-h)
      cat <<USAGE
Usage: scripts/discord_ops_notify.sh [options]
  --status <pass|warn|fail|unknown>
  --summary "PASS=3 WARN=0 FAIL=0"
  --details "• Phase 1 — PASS\n• Phase 2 — WARN"
  --link <https://report>
  --channel <channel-name>
  --title <message title>
  --counts "PASS=3 WARN=0 FAIL=0" (alias for --summary)
USAGE
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "${DISCORD_WEBHOOK_DEFAULT:-}" && -z "${DISCORD_WEBHOOK_MAP:-}" ]]; then
  echo "Discord webhook not configured; skipping notification."
  echo "DISCORD_RESULT=SKIP"
  exit 0
fi

normalize_status() {
  local value="${1:-}"
  case "${value,,}" in
    pass|ok|success) echo "pass" ;;
    warn|warning) echo "warn" ;;
    fail|failed|error) echo "fail" ;;
    *) echo "unknown" ;;
  esac
}

STATUS=$(normalize_status "$STATUS")
local_level="info"
local_emoji="ℹ️"
local_status_label="STATUS"
case "$STATUS" in
  pass)
    local_level="info"
    local_emoji="✅"
    local_status_label="PASS"
    ;;
  warn)
    local_level="warn"
    local_emoji="⚠️"
    local_status_label="WARN"
    ;;
  fail)
    local_level="error"
    local_emoji="❌"
    local_status_label="FAIL"
    ;;
  *)
    local_level="info"
    local_emoji="ℹ️"
    local_status_label="STATUS"
    ;;
esac

if [[ -n "$COUNTS" && -z "$SUMMARY" ]]; then
  SUMMARY="$COUNTS"
fi

trimmed_summary="${SUMMARY## }"
trimmed_summary="${trimmed_summary%% }"

message_lines=()
message_lines+=("$local_emoji $TITLE — ${local_status_label}")
if [[ -n "$trimmed_summary" ]]; then
  message_lines+=("$trimmed_summary")
fi
if [[ -n "$DETAILS" ]]; then
  message_lines+=("$DETAILS")
fi
if [[ -n "$REPORT_LINK" ]]; then
  message_lines+=("Latest report: $REPORT_LINK")
fi

content=$(printf '%s\n' "${message_lines[@]}")
if [[ ${#content} -gt 1800 ]]; then
  content="${content:0:1790}\n…"
fi

export DISCORD_CONTENT="$content"
export DISCORD_LEVEL="$local_level"
export DISCORD_CHANNEL="$CHANNEL"

payload=$(python3 - <<'PY'
import json, os
content = os.environ.get('DISCORD_CONTENT', '')
level = os.environ.get('DISCORD_LEVEL', 'info')
channel = os.environ.get('DISCORD_CHANNEL', 'default')
print(json.dumps({
    'content': content,
    'level': level,
    'channel': channel
}))
PY
)

send_request() {
  curl -sS -m "$TIMEOUT_SECONDS" -w "\n%{http_code}" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "$API_URL" 2>/tmp/discord_notify_error.log || echo "\n000"
}

attempt=1
result_code="WARN"
response_body=""
http_code=""
while [[ $attempt -le $MAX_ATTEMPTS ]]; do
  response=$(send_request)
  # Extract HTTP code (last line) and body (everything before last line)
  http_code=$(echo "$response" | tail -n 1)
  body=$(echo "$response" | sed '$d')  # Remove last line (macOS compatible)
  if [[ "$http_code" == "200" ]]; then
    result_code="PASS"
    response_body="$body"
    break
  elif [[ "$http_code" == "503" ]]; then
    echo "Discord bridge reports webhook is not configured (503)."
    echo "DISCORD_RESULT=SKIP"
    exit 0
  elif [[ "$http_code" =~ ^5 && $attempt -lt $MAX_ATTEMPTS ]]; then
    echo "Discord notify attempt $attempt failed with $http_code, retrying..."
    sleep "$RETRY_DELAY"
    attempt=$((attempt + 1))
    continue
  else
    result_code="WARN"
    response_body="$body"
    break
  fi
done

rm -f /tmp/discord_notify_error.log >/dev/null 2>&1 || true

echo "$response_body"
if [[ "$result_code" == "PASS" ]]; then
  echo "Discord notification delivered (HTTP $http_code)."
else
  echo "Discord notification encountered issues (HTTP ${http_code:-000})."
fi
echo "DISCORD_RESULT=$result_code"
exit 0
