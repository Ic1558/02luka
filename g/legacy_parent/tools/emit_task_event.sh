#!/usr/bin/env bash
# Emit a CLC/Cursor task event to both Redis (if available) and memory files.
set -euo pipefail
SOT="${SOT:-$HOME/dev/02luka-repo}"
MEM="${MEM:-$SOT/a/memory}"
LOGD="${LOGD:-$HOME/Library/Logs/02luka}"
mkdir -p "$MEM" "$LOGD"

agent="${1:-unknown}"
action="${2:-unknown}"
status="${3:-info}"
context="${4:-}"
id="${5:-WO-$(date +%y%m%d-%H%M%S)-$}"

ts="$(date -Iseconds)"
event=$(jq -nc --arg agent "$agent" --arg action "$action" --arg status "$status" --arg context "$context" --arg id "$id" --arg ts "$ts" \
  '{ts:$ts,id:$id,agent:$agent,action:$action,status:$status,context:$context}')

# Append to JSONL
echo "$event" >> "$MEM/active_tasks.jsonl"

# Update snapshot (keep last N per agent)
N=${N:-20}
jq -s --argjson N "$N" '
  (.[0] // {}) as $snap
  | (.[1:] // []) as $events
  | ($events | sort_by(.ts) | group_by(.agent) | map(.[-($N):]) | add) as $last
  | {timestamp: now | todate, tasks: ($last // [])}
' "$MEM/active_tasks.json" <(tail -n 1000 "$MEM/active_tasks.jsonl" 2>/dev/null || true) \
   > "$MEM/.active_tasks.json.tmp" 2>>"$LOGD/task_bus.err" || true
mv -f "$MEM/.active_tasks.json.tmp" "$MEM/active_tasks.json" 2>/dev/null || true

# Publish to redis if available
if command -v redis-cli >/dev/null 2>&1; then
  (echo "$event" | redis-cli -x PUBLISH mcp:tasks >/dev/null 2>&1) || true
fi

echo "$event"
