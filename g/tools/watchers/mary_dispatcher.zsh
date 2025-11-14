#!/usr/bin/env zsh
set -euo pipefail

setopt null_glob

ROOT="${HOME}/02luka"
INBOX="$ROOT/bridge/inbox/ENTRY"
OUTBOX="$ROOT/bridge/outbox/ENTRY"
LOG_DIR="$ROOT/logs"
LOG_FILE="$LOG_DIR/mary_dispatcher.log"

mkdir -p "$INBOX" "$OUTBOX" "$LOG_DIR"

log() {
  printf '[%s] %s\n' "$(date -Iseconds)" "$*" >> "$LOG_FILE"
}

log "start mary_dispatcher"

for file in "$INBOX"/*.yaml; do
  [[ -f "$file" ]] || continue
  id="${${file:t}%.*}"

  dest="CLC"
  if grep -q '^strict_target: *true' "$file" 2>/dev/null; then
    if grep -q 'target_candidates: *\[ *shell *\]' "$file" 2>/dev/null; then
      dest="shell"
    else
      dest="CLC"
    fi
  fi

  mkdir -p "$ROOT/bridge/inbox/$dest" "$ROOT/bridge/outbox/$dest"
  tmp="$ROOT/bridge/inbox/$dest/.mary_${id}.$$"
  cp "$file" "$tmp"
  mv "$tmp" "$ROOT/bridge/inbox/$dest/${id}.yaml"
  mv "$file" "$OUTBOX/${id}.yaml"
  log "$id -> $dest"
done
