#!/usr/bin/env zsh
set -euo pipefail
BASE="$HOME/02luka"
CONFIG="$BASE/config"
LOGS="$BASE/logs"
MAP="$CONFIG/nlp_command_map.yaml"
LOG="$LOGS/gg_nlp_bridge.$(date +%Y%m%d_%H%M%S).log"
CHANNEL_IN="gg:nlp"
CHANNEL_OUT="shell"
TASK_PREFIX="gg-nlp"

if [[ -f "$CONFIG/kim.env" ]]; then
  set -a
  source "$CONFIG/kim.env"
  set +a
fi

REDIS_HOST="${REDIS_HOST:-127.0.0.1}"
REDIS_PORT="${REDIS_PORT:-6379}"
REDIS_PASSWORD="${REDIS_PASSWORD:-}"
CHANNEL_IN="${REDIS_CHANNEL_IN:-$CHANNEL_IN}"
redis_args=(-h "$REDIS_HOST" -p "$REDIS_PORT")
[[ -n "$REDIS_PASSWORD" ]] && redis_args+=(-a "$REDIS_PASSWORD")
exec > >(tee -a "$LOG") 2>&1
echo "== [gg_nlp_bridge] PID $$ =="

intent_for() {
  local key="$1"
  local intent
  # Fixed AWK pattern - removed any potential debug markers
  intent="$(awk -v k="$key" '
    /^synonyms:/ {in_syn=1; next}
    /^intents:/ {in_syn=0}
    in_syn && $0 ~ ":" {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
      if (match($0, /^"?([^"]+)"?[[:space:]]*:[[:space:]]*([a-zA-Z0-9_.-]+)$/, a)) {
        if (a[1] == k) { print a[2]; exit }
      }
    }
  ' "$MAP" 2>/dev/null)"
  [[ -n "$intent" ]] && { echo "$intent"; return 0; }
  echo "$key"
}

cmd_for_intent() {
  local intent="$1"
  awk -v i="$intent" '
    /^intents:/ {in_int=1; next}
    in_int && /^[[:space:]]+[a-zA-Z0-9_.-]+:/ {
      if (match($0, /^[[:space:]]+([a-zA-Z0-9_.-]+):/, b)) { k=b[1] }
    }
    in_int && $0 ~ /^[[:space:]]+cmd:/ {
      if (k==i) {
        sub(/^[[:space:]]+cmd:[[:space:]]*/, "", $0)
        gsub(/^"|"$/, "", $0)
        print $0; exit
      }
    }
  ' "$MAP"
}

publish_shell_task() {
  local cmd="$1"
  local tid="${TASK_PREFIX}:$(date +%s)-$RANDOM"
  local json
  json="$(jq -n --arg tid "$tid" --arg cmd "$cmd" \
    '{task_id:$tid, type:"shell", cmd:$cmd, timeout_sec:3600 }')"
  echo "Dispatch → $CHANNEL_OUT: $json"
  redis-cli "${redis_args[@]}" PUBLISH "$CHANNEL_OUT" "$json" >/dev/null
  echo "$tid"
}

echo "Subscribing to $CHANNEL_IN …"
redis-cli --raw "${redis_args[@]}" SUBSCRIBE "$CHANNEL_IN" | while read -r line; do
  if [[ "$line" == "message" ]]; then
    read -r chan
    read -r payload
    echo "-- incoming on $chan: $payload"
    local key intent cmd tid
    key="$(echo "$payload" | jq -r '(.intent // .text // "")' 2>/dev/null || echo "")"
    [[ -z "$key" || "$key" == "null" ]] && { echo "WARN: no intent/text"; continue; }
    intent="$(intent_for "$key")"
    cmd="$(cmd_for_intent "$intent")"
    [[ -z "$cmd" ]] && { echo "WARN: intent '$intent' not whitelisted"; continue; }
    tid="$(publish_shell_task "$cmd")"
    echo "ACK: intent '$intent' → task_id=$tid"
  fi
done
