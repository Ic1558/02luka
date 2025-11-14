#!/usr/bin/env zsh
set -euo pipefail
setopt null_glob

ROOT="${HOME}/02luka"
INBOX="$ROOT/bridge/inbox/CLC"
OUTBOX="$ROOT/bridge/outbox/CLC"
LOG_DIR="$ROOT/logs"
LOG_FILE="$LOG_DIR/clc_bridge.log"

mkdir -p "$INBOX" "$OUTBOX" "$LOG_DIR"

log() {
  printf '[%s] %s\n' "$(date -Iseconds)" "$*" >> "$LOG_FILE"
}

log "start clc_bridge"

for file in "$INBOX"/*.yaml; do
  [[ -f "$file" ]] || continue
  id="${${file:t}%.*}"
  norm="$INBOX/${id}.yaml"
  if [[ "$file" != "$norm" ]]; then
    mv "$file" "$norm"
    log "normalized $id"
  else
    log "already normalized $id"
  fi
  cp "$norm" "$OUTBOX/${id}.yaml"
done
