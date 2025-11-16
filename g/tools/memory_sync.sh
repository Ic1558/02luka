#!/bin/sh
set -eu
MEMORY_FILE="${LUKA_SOT:-$HOME/02luka}/shared_memory/context.json"
BRIDGE_DIR="${LUKA_SOT:-$HOME/02luka}/bridge/memory"
mkdir -p "$BRIDGE_DIR/outbox"
tmp="$(mktemp)"
timestamp() { date -Iseconds; }
case "${1:-}" in
  update)
    agent="${2:?ERROR: agent required}"
    status="${3:?ERROR: status required}"
    jq --arg a "$agent" --arg s "$status" --arg ts "$(timestamp)" \
      '.last_update=$ts | .agents[$a] = (.agents[$a] // {}) + {status:$s,last_seen:$ts}' \
      "$MEMORY_FILE" > "$tmp" && mv "$tmp" "$MEMORY_FILE"
    printf '{"event":"agent_update","agent":"%s","status":"%s","ts":"%s"}\n' "$agent" "$status" "$(timestamp)" \
      > "$BRIDGE_DIR/outbox/$(date +%s)_broadcast.json"
    ;;
  get) cat "$MEMORY_FILE" ;;
  *) echo "Usage: $0 {update|get} [agent] [status]" >&2; exit 1 ;;
esac
