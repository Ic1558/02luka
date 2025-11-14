#!/usr/bin/env zsh
set -euo pipefail

setopt null_glob

ROOT="${HOME}/02luka"
INBOX="$ROOT/bridge/inbox/shell"
OUTBOX="$ROOT/bridge/outbox/shell"
LOG_DIR="$ROOT/logs"
LOG_FILE="$LOG_DIR/shell_watcher.log"

mkdir -p "$INBOX" "$OUTBOX" "$LOG_DIR"

log() {
  printf '[%s] %s\n' "$(date -Iseconds)" "$*" >> "$LOG_FILE"
}

redis_publish() {
  local payload="$1"
  if ! command -v redis-cli >/dev/null 2>&1; then
    return 127
  fi
  local host="${REDIS_HOST:-127.0.0.1}"
  local port="${REDIS_PORT:-6379}"
  local password="${REDIS_PASS:-}"
  if [[ -n "$password" ]]; then
    redis-cli -h "$host" -p "$port" -a "$password" PUBLISH shell "$payload" >/dev/null
  else
    redis-cli -h "$host" -p "$port" PUBLISH shell "$payload" >/dev/null
  fi
}

log "start shell_watcher"

for file in "$INBOX"/*.yaml; do
  [[ -f "$file" ]] || continue
  id="${${file:t}%.*}"
  body=$(base64 "$file" | tr -d '\n')
  message="{\"task_id\":\"$id\",\"agent\":\"shell\",\"kind\":\"yaml\",\"body_base64\":\"$body\"}"

  if redis_publish "$message"; then
    log "published $id to redis channel shell"
  else
    log "WARN redis publish failed for $id; using file queue"
  fi

  mv "$file" "$OUTBOX/${id}.yaml"
done
