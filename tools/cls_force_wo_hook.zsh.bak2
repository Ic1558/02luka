#!/usr/bin/env zsh
set -euo pipefail

# -------------------------------------------------------------------
# CLS Force WO Hook: atomic drop to CLC inbox when task is stuck
# -------------------------------------------------------------------
: "${LUKA_HOME:=$HOME/02luka}"
: "${INBOX:=$LUKA_HOME/bridge/inbox/CLC}"
: "${HISTORY:=$LUKA_HOME/logs/wo_drop_history}"
: "${SRC_JSON:=$LUKA_HOME/hub/delegation_watchdog.json}"   # default input
: "${WO_KIND:=CLS_FORCE_WO}"
: "${DRY_RUN:=0}"

mkdir -p "$INBOX" "$HISTORY"

ts_utc() { date -u +'%Y%m%d_%H%M%S'; }

mk_wo_body() {
  # $1 = task_id, $2 = reason, $3 = meta(json string or empty)
  local task_id="$1" reason="$2" meta="${3:-{}}"
  cat <<JSON
{
  "_meta": {
    "created_at": "$(date -u +%FT%TZ)",
    "created_by": "GG_Agent_02luka",
    "kind": "${WO_KIND}"
  },
  "task": {
    "id": "${task_id}",
    "force": true,
    "reason": "${reason}"
  },
  "route": {
    "target": "CLC",
    "priority": "high"
  },
  "meta": ${meta}
}
JSON
}

drop_atomic() {
  # $1 = filename prefix, $2 = json content
  local pref="$1" body="$2"
  local tmp="$(mktemp)"
  print -r -- "$body" > "$tmp"

  local base="${pref}_$(ts_utc).json"
  local dest="$INBOX/$base"
  local hist="$HISTORY/$base"

  if [[ "$DRY_RUN" = "1" ]]; then
    echo "[DRY-RUN] would mv $tmp -> $dest"
    rm -f "$tmp"
    return 0
  fi

  mv "$tmp" "$dest"
  cp -f "$dest" "$hist"

  # quick verify — existence in inbox or processed/outbox
  if [[ -f "$dest" ]]; then
    echo "✅ WO dropped: $dest"
  else
    echo "⚠️  WO not found in inbox after mv (may be processed instantly)."
  fi

  # list current state for audit
  echo "📦 inbox:";      ls -1 "$INBOX"    | tail -5 || true
  echo "🗂 history:";    ls -1 "$HISTORY"  | tail -5 || true
}

# Read watchdog results (JSON)
json_in="$(cat "${1:-$SRC_JSON}")"

# Parse stuck items with jq
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required" >&2; exit 2
fi

count="$(print -r -- "$json_in" | jq -r '(.items // []) | length')"
echo "Found $count items in watchdog report"

# Select only stuck items
print -r -- "$json_in" | jq -c '.items[] | select(.stuck==true)' | while IFS= read -r item; do
  task_id="$(print -r -- "$item" | jq -r '.id // .label // "unknown")"
  reason="$(print -r -- "$item" | jq -r '.reason // "stuck"')"
  meta="$(print -r -- "$item" | jq -c 'del(.reason, .stuck)')"

  body="$(mk_wo_body "$task_id" "$reason" "$meta")"
  drop_atomic "WO-CLS-FORCE_${task_id}" "$body"
done

echo "Done."
