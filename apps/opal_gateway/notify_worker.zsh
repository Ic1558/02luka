#!/usr/bin/env zsh
# Notification Worker v1.0
# Processes notification files from bridge/inbox/NOTIFY/ and sends via Telegram
#
# Canonical spec: g/reports/feature_notification_system_v1_complete_PLAN.md

set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

# --- Configuration ---
LUKA_HOME="${LUKA_HOME:-$HOME/02luka}"
ENV_FILE="$LUKA_HOME/.env.local"
NOTIFY_INBOX="$LUKA_HOME/bridge/inbox/NOTIFY"
PROCESSED_DIR="$LUKA_HOME/bridge/processed/NOTIFY"
FAILED_DIR="$LUKA_HOME/bridge/failed/NOTIFY"
LOG_FILE="$LUKA_HOME/g/telemetry/notify_worker.jsonl"
STALE_HOURS=24
POLL_INTERVAL=5
MAX_RETRIES=3

# --- Startup Guard ---
if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: .env.local not found at $ENV_FILE" >&2
  exit 1
fi

# Load .env.local
set -o allexport
source "$ENV_FILE"
set +o allexport

# Check critical env vars
if [[ -z "${TELEGRAM_SYSTEM_ALERT_BOT_TOKEN:-}" ]]; then
  echo "ERROR: TELEGRAM_SYSTEM_ALERT_BOT_TOKEN not set in .env.local" >&2
  echo "Worker cannot start without bot token. Exiting." >&2
  exit 1
fi

if [[ -z "${TELEGRAM_SYSTEM_ALERT_CHAT_ID:-}" ]]; then
  echo "ERROR: TELEGRAM_SYSTEM_ALERT_CHAT_ID not set in .env.local" >&2
  echo "Worker cannot start without chat ID. Exiting." >&2
  exit 1
fi

echo "[OK] Startup guard passed - Notification Worker v1.0 starting..."
echo "   NOTIFY_INBOX: $NOTIFY_INBOX"
echo "   LOG_FILE: $LOG_FILE"

# Ensure directories exist
mkdir -p "$PROCESSED_DIR" "$FAILED_DIR" "$(dirname "$LOG_FILE")"

# --- Helper Functions ---

# Resolve chat_id from chat name
resolve_chat_id() {
  local chat_name="$1"
  local chat_id=""
  
  case "$chat_name" in
    "boss_private")
      chat_id="${TELEGRAM_SYSTEM_ALERT_CHAT_ID:-${TELEGRAM_BOT_CHAT_ID_GPT_ALERTS:-${TELEGRAM_GUARD_CHAT_ID:-}}}"
      ;;
    "ops")
      chat_id="${TELEGRAM_BOT_CHAT_ID_EDGEWORK:-${TELEGRAM_SYSTEM_ALERT_CHAT_ID:-${TELEGRAM_BOT_CHAT_ID_GPT_ALERTS:-${TELEGRAM_GUARD_CHAT_ID}}}}"
      ;;
    "general")
      chat_id="${TELEGRAM_SYSTEM_ALERT_CHAT_ID:-${TELEGRAM_BOT_CHAT_ID_GPT_ALERTS:-${TELEGRAM_GUARD_CHAT_ID:-}}}"
      ;;
    *)
      chat_id="${TELEGRAM_SYSTEM_ALERT_CHAT_ID:-${TELEGRAM_BOT_CHAT_ID_GPT_ALERTS:-${TELEGRAM_GUARD_CHAT_ID:-}}}"
      ;;
  esac
  
  if [[ -z "$chat_id" ]]; then
    echo "ERROR: No chat_id found for chat: $chat_name" >&2
    return 1
  fi
  echo "$chat_id"
}

# Resolve bot token based on chat name
resolve_bot_token() {
  local chat_name="$1"
  local token=""
  
  case "$chat_name" in
    "boss_private")
      token="${TELEGRAM_SYSTEM_ALERT_BOT_TOKEN:-${TELEGRAM_BOT_TOKEN_GPT_ALERTS:-${TELEGRAM_GUARD_BOT_TOKEN:-}}}"
      ;;
    "ops")
      # Use GUARD bot per Boss recommendation, EDGEWORK as fallback
      token="${TELEGRAM_GUARD_BOT_TOKEN:-${TELEGRAM_BOT_TOKEN_EDGEWORK:-${TELEGRAM_SYSTEM_ALERT_BOT_TOKEN:-${TELEGRAM_BOT_TOKEN_GPT_ALERTS}}}}"
      ;;
    "general")
      token="${TELEGRAM_SYSTEM_ALERT_BOT_TOKEN:-${TELEGRAM_BOT_TOKEN_GPT_ALERTS:-${TELEGRAM_GUARD_BOT_TOKEN:-}}}"
      ;;
    *)
      token="${TELEGRAM_SYSTEM_ALERT_BOT_TOKEN:-${TELEGRAM_BOT_TOKEN_GPT_ALERTS:-${TELEGRAM_GUARD_BOT_TOKEN:-}}}"
      ;;
  esac
  
  if [[ -z "$token" ]]; then
    echo "ERROR: No bot token found for chat: $chat_name" >&2
    return 1
  fi
  echo "$token"
}

# Check if notification file is stale (>24 hours old)
is_stale_notification() {
  local file_path="$1"
  
  if [[ ! -f "$file_path" ]]; then
    return 1
  fi
  
  local file_age_seconds=$(($(date +%s) - $(stat -f %m "$file_path" 2>/dev/null || echo 0)))
  local file_age_hours=$((file_age_seconds / 3600))
  
  if [[ $file_age_hours -gt $STALE_HOURS ]]; then
    return 0  # Is stale
  fi
  return 1  # Not stale
}

# Log metric to JSONL file
log_metric() {
  local wo_id="$1"
  local result="$2"
  local channel="$3"
  local chat="${4:-}"
  local attempts="${5:-1}"
  local http_code="${6:-0}"
  local reason="${7:-}"
  local file_age_hours="${8:-0}"
  
  local timestamp
  timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  
  # Normalize values
  if [[ "$chat" == "" || "$chat" == "unknown" ]]; then
    chat="null"
  else
    chat="\"$chat\""
  fi
  
  if [[ "$http_code" == "0" || "$http_code" == "" || "$http_code" == "null" ]]; then
    http_code="null"
  fi
  
  if [[ "$reason" == "" || "$reason" == "null" ]]; then
    reason="null"
  else
    reason="\"$reason\""
  fi
  
  if [[ "$file_age_hours" == "0" || "$file_age_hours" == "" || "$file_age_hours" == "null" ]]; then
    file_age_hours="null"
  fi
  
  # Build JSON entry using printf (avoids quote issues)
  local json_line
  json_line=$(printf '{"timestamp":"%s","wo_id":"%s","result":"%s","channel":"%s","chat":%s,"attempts":%s,"http_code":%s,"reason":%s,"file_age_hours":%s}\n' \
    "$timestamp" "$wo_id" "$result" "$channel" "$chat" "$attempts" "$http_code" "$reason" "$file_age_hours")
  echo "$json_line" >> "$LOG_FILE"
}

# Send Telegram message with retry
send_telegram_with_retry() {
  local chat_id="$1"
  local text="$2"
  local token="$3"
  local wo_id="$4"
  local chat_name="$5"
  local max_retries=$MAX_RETRIES
  local delay=2
  
  for attempt in $(seq 0 $max_retries); do
    if [[ $attempt -gt 0 ]]; then
      local backoff_delay=$((delay * (2 ** (attempt - 1))))
      echo "  [RETRY] Retry attempt $attempt after ${backoff_delay}s delay..." >&2
      log_metric "$wo_id" "retry" "telegram" "$chat_name" "$attempt" "0" "retry_attempt" "0"
      sleep "$backoff_delay"
    fi
    
    # Send API request
    local response=$(curl -sS -w "\n%{http_code}" --max-time 10 \
      -X POST "https://api.telegram.org/bot${token}/sendMessage" \
      -d "chat_id=${chat_id}" \
      -d "text=${text}" \
      -d "parse_mode=Markdown" 2>&1)
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    # Success
    if [[ "$http_code" == "200" ]]; then
      echo "  [OK] Telegram sent successfully"
      log_metric "$wo_id" "success" "telegram" "$chat_name" "$((attempt + 1))" "200" "success" "0"
      return 0
    fi
    
    # Client errors (no retry)
    if [[ "$http_code" =~ ^(400|401|403)$ ]]; then
      echo "  [ERROR] Client error ($http_code): $body" >&2
      log_metric "$wo_id" "failed" "telegram" "$chat_name" "$((attempt + 1))" "$http_code" "client_error" "0"
      return 1
    fi
    
    # Server errors (retry)
    if [[ "$http_code" =~ ^(429|500|502|503|504)$ ]]; then
      echo "  [WARN] Server error ($http_code), will retry..." >&2
      continue
    fi
    
    # Other errors
    echo "  [ERROR] Unexpected error ($http_code): $body" >&2
  done
  
  # All retries exhausted
  echo "  [ERROR] Failed after $max_retries retries" >&2
  log_metric "$wo_id" "failed" "telegram" "$chat_name" "$((max_retries + 1))" "$http_code" "all_retries_exhausted" "0"
  return 1
}

# Process a single notification file
process_notification_file() {
  local notify_file="$1"
  local wo_id=$(basename "$notify_file" _notify.json | sed 's/\.json$//')
  
  echo ""
  echo "[PROCESS] Processing: $wo_id"
  
  # Check if stale
  if is_stale_notification "$notify_file"; then
    local file_age_seconds=$(($(date +%s) - $(stat -f %m "$notify_file" 2>/dev/null || echo 0)))
    local file_age_hours=$((file_age_seconds / 3600))
    echo "  [WARN] Stale notification (${file_age_hours}h old), skipping..."
    log_metric "$wo_id" "skipped" "telegram" "unknown" "1" "0" "stale" "$file_age_hours"
    mv "$notify_file" "$FAILED_DIR/$(basename "$notify_file" .json)_stale.json" 2>/dev/null || true
    return 0
  fi
  
  # Read JSON payload
  if [[ ! -f "$notify_file" ]]; then
    echo "  [ERROR] File not found: $notify_file" >&2
    return 1
  fi
  
  local payload=$(cat "$notify_file")
  
  # Extract Telegram config
  local telegram_enabled=$(echo "$payload" | jq -r '.telegram // empty')
  if [[ -z "$telegram_enabled" || "$telegram_enabled" == "null" ]]; then
    echo "  [WARN] No Telegram config found, skipping..."
    log_metric "$wo_id" "skipped" "telegram" "unknown" "1" "0" "no_telegram_config" "0"
    mv "$notify_file" "$PROCESSED_DIR/" 2>/dev/null || true
    return 0
  fi
  
  local chat_name=$(echo "$payload" | jq -r '.telegram.chat // "boss_private"')
  local text=$(echo "$payload" | jq -r '.telegram.text // ""')
  
  if [[ -z "$text" ]]; then
    echo "  [ERROR] No text found in Telegram config" >&2
    log_metric "$wo_id" "failed" "telegram" "$chat_name" "1" "0" "no_text" "0"
    mv "$notify_file" "$FAILED_DIR/" 2>/dev/null || true
    return 1
  fi
  
  # Resolve chat_id and token
  local chat_id
  chat_id=$(resolve_chat_id "$chat_name")
  local resolve_status=$?
  if [[ $resolve_status -ne 0 ]]; then
    echo "  [ERROR] Failed to resolve chat_id for: $chat_name" >&2
    log_metric "$wo_id" "failed" "telegram" "$chat_name" "1" "0" "chat_id_resolution_failed" "0"
    mv "$notify_file" "$FAILED_DIR/" 2>/dev/null || true
    return 1
  fi
  
  local token
  token=$(resolve_bot_token "$chat_name")
  local token_status=$?
  if [[ $token_status -ne 0 ]]; then
    echo "  [ERROR] Failed to resolve bot token for: $chat_name" >&2
    log_metric "$wo_id" "failed" "telegram" "$chat_name" "1" "0" "token_resolution_failed" "0"
    mv "$notify_file" "$FAILED_DIR/" 2>/dev/null || true
    return 1
  fi
  
  echo "  -> Chat: $chat_name (ID: $chat_id)"
  local text_preview
  text_preview="${text:0:60}"
  echo "  -> Text: $text_preview..."
  
  # Send Telegram message
  if send_telegram_with_retry "$chat_id" "$text" "$token" "$wo_id" "$chat_name"; then
    echo "  [OK] Notification sent successfully"
    mv "$notify_file" "$PROCESSED_DIR/" 2>/dev/null || true
    return 0
  else
    echo "  [ERROR] Failed to send notification"
    mv "$notify_file" "$FAILED_DIR/" 2>/dev/null || true
    return 1
  fi
}

# --- Main Loop ---
echo ""
echo "[START] Starting notification worker loop (polling every ${POLL_INTERVAL}s)..."
echo "   Press Ctrl+C to stop"
echo ""

# Trap SIGINT/SIGTERM for graceful shutdown
trap 'echo ""; echo "[SHUTDOWN] Shutting down notification worker..."; exit 0' INT TERM

while true; do
  # Find all notification files (skip .tmp files)
  local notify_files=($(find "$NOTIFY_INBOX" -name "*.json" -type f 2>/dev/null | grep -v "\.tmp$" || true))
  
  if [[ ${#notify_files[@]} -eq 0 ]]; then
    sleep "$POLL_INTERVAL"
    continue
  fi
  
  for notify_file in "${notify_files[@]}"; do
    process_notification_file "$notify_file" || true
  done
  
  sleep "$POLL_INTERVAL"
done
