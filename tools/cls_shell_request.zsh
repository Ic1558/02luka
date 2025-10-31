#!/usr/bin/env zsh
set -euo pipefail

: "${REDIS_HOST:=host.docker.internal}"
: "${REDIS_PORT:=6379}"
: "${REDIS_PASSWORD:=changeme-02luka}"

if ! command -v redis-cli >/dev/null 2>&1; then
  echo "❌ redis-cli not found. Install or add to PATH." >&2
  exit 127
fi

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 '<command>' [timeout_sec]" >&2
  exit 2
fi

CMD="$1"
TIMEOUT="${2:-60}"

TASK_ID="CLS-$(date +%Y%m%d%H%M%S)-$RANDOM"
REPLY_KEY="shell:response:shell:${TASK_ID}"

payload=$(jq -cn --arg tid "$TASK_ID" --arg cmd "$CMD" --arg rk "$REPLY_KEY" '
  {type:"shell", task_id:$tid, command:$cmd, reply_key:$rk, created_at:now|todate}')
# fallback if jq missing
if [[ -z "${payload}" || "${payload}" == "null" ]]; then
  payload="{\"type\":\"shell\",\"task_id\":\"$TASK_ID\",\"command\":\"$CMD\",\"reply_key\":\"$REPLY_KEY\",\"created_at\":\"$(date -Iseconds)\"}"
fi

redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -a "$REDIS_PASSWORD" PUBLISH shell "$payload" >/dev/null

# Wait for response on a dedicated list key (Terminalhandler should LPUSH it)
# Key pattern: shell:response:shell:<TASK_ID>
RESP_OUTPUT=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -a "$REDIS_PASSWORD" \
  BRPOP "$REPLY_KEY" "$TIMEOUT" 2>&1)
RESP_STATUS=$?
RESP_RAW=$(printf '%s\n' "$RESP_OUTPUT" | tail -n1)

if [[ $RESP_STATUS -ne 0 ]]; then
  if [[ "$RESP_RAW" == "(nil)" ]]; then
    echo "⏱️  No response within ${TIMEOUT}s. task_id=${TASK_ID}"
    echo "$TASK_ID"
    exit 0
  fi

  echo "❌ redis-cli BRPOP failed (exit $RESP_STATUS). task_id=${TASK_ID}" >&2
  printf '%s\n' "$RESP_OUTPUT" >&2
  exit $RESP_STATUS
fi

if [[ "$RESP_RAW" == "(nil)" ]]; then
  echo "⏱️  No response within ${TIMEOUT}s. task_id=${TASK_ID}"
  echo "$TASK_ID"
  exit 0
fi

if [[ -z "$RESP_RAW" ]]; then
  echo "❓ Empty response received. task_id=${TASK_ID}" >&2
  exit 1
fi

echo "$RESP_RAW"
