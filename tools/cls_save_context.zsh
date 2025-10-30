#!/usr/bin/env bash
set -euo pipefail
LOG_FILE="${HOME}/02luka/g/logs/cls_phase3.log"
SESSION_CONTEXT="${HOME}/02luka/memory/cls/session_context.json"
LEARNING_DB="${HOME}/02luka/memory/cls/learning_db.jsonl"
ensure_dirs(){ mkdir -p "$(dirname "$LOG_FILE")" "$(dirname "$SESSION_CONTEXT")" "$(dirname "$LEARNING_DB")" || true; }
log(){ ensure_dirs; echo "[$(date +%Y-%m-%dT%H:%M:%S%z)] SAVE $1" >> "$LOG_FILE"; }
append_session(){ ensure_dirs; printf "%s\n" "$1" >> "$SESSION_CONTEXT"; }
case "${1:-session}" in
  session)
    sid="${2:-$(date +%s)}"; ctype="${3:-manual}"; data="${4:-{}}"
    entry="{\"timestamp\":\"$(date +%Y-%m-%dT%H:%M:%S%z)\",\"session_id\":\"$sid\",\"context_type\":\"$ctype\",\"context_data\":$data,\"saved_by\":\"cls_save_context\"}"
    append_session "$entry"
    printf "%s\n" "$entry" >> "$LEARNING_DB"
    log "session saved sid=$sid type=$ctype"
    ;;
  *) echo "Usage: $0 session <session_id> [context_type] [context_data]"; exit 1;;
esac
