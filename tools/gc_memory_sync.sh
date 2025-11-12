#!/bin/sh
set -eu

export LUKA_SOT="${LUKA_SOT:-$HOME/02luka}"
MEM_SYNC="$LUKA_SOT/tools/memory_sync.sh"
INBOX="$LUKA_SOT/bridge/memory/inbox"

gc_mem_update() {
  "$MEM_SYNC" update gc active >/dev/null
}

gc_mem_push() {
  body="${1:?json_string required}"
  ts=$(date +%s)
  # Validate JSON before writing
  echo "$body" | jq . >/dev/null || { echo "ERROR: Invalid JSON" >&2; exit 1; }
  echo "$body" | jq . > "$INBOX/gc_context_${ts}.json"
}

gc_mem_get() {
  "$MEM_SYNC" get | jq '.agents.gc? // {}'
}

case "${1:-}" in
  update) gc_mem_update ;;
  push)   gc_mem_push "${2:-"{}"}" ;;
  get)    gc_mem_get ;;
  *) echo "Usage: $(basename "$0") {update|push <json>|get}" >&2; exit 1 ;;
esac
