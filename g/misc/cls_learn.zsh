#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="${HOME}/02luka/g/logs/cls_phase3.log"
LEARNING_DB="${HOME}/02luka/memory/cls/learning_db.jsonl"
SESSION_CONTEXT="${HOME}/02luka/memory/cls/session_context.json"

ensure_dirs() {
  mkdir -p "$(dirname "$LOG_FILE")" "$(dirname "$LEARNING_DB")" || true
}

log() {
  ensure_dirs
  echo "[$(date +%Y-%m-%dT%H:%M:%S%z)] LEARN $1" >> "$LOG_FILE"
}

json_escape() { sed 's/\\/\\\\/g; s/"/\\"/g'; }

learn_interaction() {
  local interaction_type="$1"
  local content="$2"
  local context="${3:-}"
  local metadata_json="${4:-{}}"

  ensure_dirs
  local ts session_id
  ts=$(date +%Y-%m-%dT%H:%M:%S%z)
  session_id="${SESSION_ID:-$(date +%s)}"

  local content_esc context_esc
  content_esc=$(printf "%s" "$content" | json_escape)
  context_esc=$(printf "%s" "$context" | json_escape)

  local entry
  entry="{\"timestamp\":\"$ts\",\"session_id\":\"$session_id\",\"interaction_type\":\"$interaction_type\",\"content\":\"$content_esc\",\"context\":\"$context_esc\",\"metadata\":$metadata_json}"

  printf "%s\n" "$entry" >> "$LEARNING_DB"
  log "captured interaction=$interaction_type session=$session_id"
}

learn_command() {
  local command_str="$1"
  local output="$2"
  local exit_code="${3:-0}"
  local working_dir="${4:-$(pwd)}"

  local cmd_esc out_len wd_esc
  cmd_esc=$(printf "%s" "$command_str" | json_escape)
  wd_esc=$(printf "%s" "$working_dir" | json_escape)
  out_len=${#output}

  local metadata
  metadata="{\"command\":\"$cmd_esc\",\"output_length\":$out_len,\"exit_code\":$exit_code,\"working_dir\":\"$wd_esc\",\"timestamp\":\"$(date +%Y-%m-%dT%H:%M:%S%z)\"}"

  learn_interaction "command" "$output" "$command_str" "$metadata"
}

case "${1:-help}" in
  command)
    learn_command "$2" "$3" "${4:-0}" "${5:-$(pwd)}"
    ;;
  *)
    echo "Usage: $0 command <cmd> <output> [exit_code] [working_dir]" >&2
    exit 1
    ;;
esac

log "done ${1:-}"




