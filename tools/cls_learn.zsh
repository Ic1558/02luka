#!/usr/bin/env bash
set -euo pipefail
LOG_FILE="${HOME}/02luka/g/logs/cls_phase3.log"
LEARNING_DB="${HOME}/02luka/memory/cls/learning_db.jsonl"
SESSION_CONTEXT="${HOME}/02luka/memory/cls/session_context.json"
ensure_dirs(){ mkdir -p "$(dirname "$LOG_FILE")" "$(dirname "$LEARNING_DB")" "$(dirname "$SESSION_CONTEXT")" || true; }
log(){ ensure_dirs; echo "[$(date +%Y-%m-%dT%H:%M:%S%z)] LEARN $1" >> "$LOG_FILE"; }
json_escape(){ awk '{gsub(/\\/,"\\\\"); gsub(/"/,"\\\""); print}'; }
learn_interaction(){ local t="$1" c="$2" k="${3:-}" m="${4:-{}}"
  ensure_dirs
  local ts sid; ts=$(date +%Y-%m-%dT%H:%M:%S%z); sid="${SESSION_ID:-$(date +%s)}"
  local cesc kesc; cesc=$(printf "%s" "$c" | json_escape); kesc=$(printf "%s" "$k" | json_escape)
  printf "%s\n" "{\"timestamp\":\"$ts\",\"session_id\":\"$sid\",\"interaction_type\":\"$t\",\"content\":\"$cesc\",\"context\":\"$kesc\",\"metadata\":$m}" >> "$LEARNING_DB"
  log "captured interaction=$t session=$sid"
}
learn_command(){ local cmd="$1" out="$2" code="${3:-0}" wd="${4:-$(pwd)}"
  local cmd_esc wd_esc out_len; cmd_esc=$(printf "%s" "$cmd" | json_escape); wd_esc=$(printf "%s" "$wd" | json_escape); out_len=${#out}
  local meta; meta="{\"command\":\"$cmd_esc\",\"output_length\":$out_len,\"exit_code\":$code,\"working_dir\":\"$wd_esc\",\"timestamp\":\"$(date +%Y-%m-%dT%H:%M:%S%z)\"}"
  learn_interaction "command" "$out" "$cmd" "$meta"
}
case "${1:-help}" in
  command) learn_command "$2" "$3" "${4:-0}" "${5:-$(pwd)}" ;;
  *) echo "Usage: $0 command <cmd> <output> [exit_code] [working_dir]"; exit 1;;
esac
log "done ${1:-}"
