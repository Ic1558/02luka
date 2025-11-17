#!/usr/bin/env zsh
set -euo pipefail

setopt null_glob

ROOT="${LUKA_SOT:-${HOME}/02luka}"
INBOX="$ROOT/bridge/inbox/ENTRY"
OUTBOX="$ROOT/bridge/outbox/ENTRY"
LOG_DIR="$ROOT/logs"
LOG_FILE="$LOG_DIR/mary_dispatcher.log"
LPE_INBOX="$ROOT/bridge/inbox/LPE"

mkdir -p "$INBOX" "$OUTBOX" "$LOG_DIR" "$LPE_INBOX" "$ROOT/bridge/outbox/LPE" "$ROOT/bridge/processed/ENTRY"

log() {
  printf '[%s] %s\n' "$(date -Iseconds)" "$*" >> "$LOG_FILE"
}

normalize_id() {
  local file="$1"
  local base="${${file:t}%.*}"
  if [[ -n "$base" ]]; then
    echo "$base"
  else
    echo "wo-$(date +%s)"
  fi
}

determine_target() {
  local file="$1"
  local dest="CLC"
  local fallback task_type
  if python3 -c "import sys,yaml,json; data=yaml.safe_load(open(sys.argv[1])) or {};\
from pathlib import Path;\
print(json.dumps({'task_type': data.get('task',{}).get('type',''), 'fallback': data.get('task',{}).get('fallback','')}))" "$file" 2>/dev/null | jq -e '.task_type=="write" and .fallback=="lpe"' >/dev/null 2>&1; then
    dest="LPE"
  elif grep -q '^strict_target: *true' "$file" 2>/dev/null; then
    if grep -q 'target_candidates: *\[ *shell *\]' "$file" 2>/dev/null; then
      dest="shell"
    else
      dest="CLC"
    fi
  fi
  echo "$dest"
}

convert_to_lpe_json() {
  local yaml_file="$1" json_out="$2" wo_id="$3"
  python3 - "$yaml_file" "$json_out" "$wo_id" <<'PY'
import json, sys, yaml, pathlib
source = pathlib.Path(sys.argv[1])
target = pathlib.Path(sys.argv[2])
wo_id = sys.argv[3]
with source.open("r", encoding="utf-8") as handle:
    data = yaml.safe_load(handle) or {}
if "id" not in data:
    data["id"] = wo_id
target.write_text(json.dumps(data), encoding="utf-8")
PY
}

log "start mary_dispatcher"

for file in "$INBOX"/*.yaml "$INBOX"/*.yml; do
  [[ -f "$file" ]] || continue
  id="$(normalize_id "$file")"

  dest="$(determine_target "$file")"
  case "$dest" in
    LPE)
      mkdir -p "$LPE_INBOX"
      tmp_json="$LPE_INBOX/.mary_${id}.$$.json"
      convert_to_lpe_json "$file" "$tmp_json" "$id"
      mv "$tmp_json" "$LPE_INBOX/${id}.json"
      cp "$file" "$OUTBOX/${id}.yaml"
      mv "$file" "$ROOT/bridge/processed/ENTRY/${id}.yaml"
      log "$id -> LPE"
      ;;
    shell|CLC)
      mkdir -p "$ROOT/bridge/inbox/$dest" "$ROOT/bridge/outbox/$dest"
      tmp="$ROOT/bridge/inbox/$dest/.mary_${id}.$$"
      cp "$file" "$tmp"
      mv "$tmp" "$ROOT/bridge/inbox/$dest/${id}.yaml"
      mv "$file" "$OUTBOX/${id}.yaml"
      log "$id -> $dest"
      ;;
    *)
      log "unknown route for $file (dest=$dest)"
      ;;
  esac

done
