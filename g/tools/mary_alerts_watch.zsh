#!/usr/bin/env zsh
# Telegram alerts for CLS .do errors >3 in 10 minutes
# Rate limit: 1 alert per 15 minutes
set -euo pipefail

REPO="$HOME/02luka"
LOG="$REPO/logs/cls_cmdin_worker.jsonl"
ALERT_LOG="$REPO/logs/mary_alerts.log"
RATE_LIMIT_FILE="$REPO/.mary_alerts_rate_limit"
ERROR_THRESHOLD=3
WINDOW_MINUTES=10
RATE_LIMIT_MINUTES=15

mkdir -p "$(dirname "$ALERT_LOG")"
touch "$ALERT_LOG"

# Check rate limit
if [[ -f "$RATE_LIMIT_FILE" ]]; then
  last_alert=$(cat "$RATE_LIMIT_FILE" 2>/dev/null || echo "0")
  now=$(date +%s)
  age=$((now - last_alert))
  if (( age < (RATE_LIMIT_MINUTES * 60) )); then
    echo "$(date +%FT%TZ) SKIP: Rate limit active (${age}s ago)" >> "$ALERT_LOG"
    exit 0
  fi
fi

# Check if log file exists
[[ -f "$LOG" ]] || exit 0

# Count errors in last WINDOW_MINUTES
window_start=$(date -v-${WINDOW_MINUTES}M +%s 2>/dev/null || date -d "${WINDOW_MINUTES} minutes ago" +%s 2>/dev/null || echo "0")
error_count=0
error_samples=()

# Parse JSONL log for errors in time window
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  
  # Extract timestamp and event
  ts=$(echo "$line" | jq -r '.ts // empty' 2>/dev/null || echo "")
  event=$(echo "$line" | jq -r '.event // empty' 2>/dev/null || echo "")
  file=$(echo "$line" | jq -r '.file // empty' 2>/dev/null || echo "")
  
  [[ "$event" != "error" ]] && continue
  
  # Parse timestamp (ISO 8601)
  ts_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$ts" +%s 2>/dev/null || \
             date -d "$ts" +%s 2>/dev/null || echo "0")
  
  if (( ts_epoch >= window_start )); then
    (( error_count++ ))
    [[ ${#error_samples[@]} -lt 3 ]] && error_samples+=("$file")
  fi
done < "$LOG"

# Check threshold
if (( error_count < ERROR_THRESHOLD )); then
  exit 0
fi

# Get Telegram config (from environment or config file)
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"

# Try to load from config file if not in env
if [[ -z "$TELEGRAM_BOT_TOKEN" ]] && [[ -f "$REPO/config/telegram.env" ]]; then
  source "$REPO/config/telegram.env"
fi

if [[ -z "$TELEGRAM_BOT_TOKEN" ]] || [[ -z "$TELEGRAM_CHAT_ID" ]]; then
  echo "$(date +%FT%TZ) WARN: Telegram config not found, skipping alert" >> "$ALERT_LOG"
  exit 0
fi

# Build alert message
samples_str=""
for sample in "${error_samples[@]}"; do
  samples_str="${samples_str}• ${sample}\n"
done

message="🚨 CLS Self-Bridge Alert

Errors detected: ${error_count} in last ${WINDOW_MINUTES} minutes (threshold: ${ERROR_THRESHOLD})

Top error samples:
${samples_str}

Quick fixes:
• Check logs: tail -f $REPO/logs/cls_cmdin_worker.log
• Health check: $REPO/tools/cls/cls_self_bridge_health.zsh
• Restart watcher: launchctl kickstart -k gui/\$(id -u)/com.02luka.cls.cmdin

Time: $(date +%FT%TZ)"

# Send Telegram alert
response=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  -H "Content-Type: application/json" \
  -d "{
    \"chat_id\": \"${TELEGRAM_CHAT_ID}\",
    \"text\": \"$(echo -e "$message" | sed 's/"/\\"/g' | tr '\n' '\\n')\",
    \"parse_mode\": \"Markdown\"
  }" 2>&1)

if echo "$response" | jq -e '.ok == true' >/dev/null 2>&1; then
  echo "$(date +%FT%TZ) ALERT SENT: ${error_count} errors" >> "$ALERT_LOG"
  echo "$(date +%s)" > "$RATE_LIMIT_FILE"
else
  echo "$(date +%FT%TZ) ALERT FAILED: $response" >> "$ALERT_LOG"
fi
