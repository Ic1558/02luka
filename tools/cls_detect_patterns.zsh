#!/usr/bin/env bash
set -euo pipefail

# Pattern Detection Tool - fixed exit_code regex

LOG_FILE="${HOME}/02luka/g/logs/cls_phase3.log"
LEARNING_DB="${HOME}/02luka/memory/cls/learning_db.jsonl"
PATTERNS_DB="${HOME}/02luka/memory/cls/patterns.jsonl"

log() {
  mkdir -p "$(dirname "$LOG_FILE")" || true
  echo "[$(date +%Y-%m-%dT%H:%M:%S%z)] DETECT $1" >> "$LOG_FILE"
}

detect_command_patterns() {
  local session_id="${1:-}"
  log "commands session=${session_id}"
  [[ -f "${LEARNING_DB}" ]] || { log "no learning_db"; return 0; }

  local rows
  rows=$(grep '"interaction_type":"command"' "${LEARNING_DB}" 2>/dev/null | head -200)
  [[ -z "${rows}" ]] && { log "no command rows"; return 0; }

  # FIX: match any non-zero integer exit_code (1,2,...,10,11,...) correctly
  local error_commands
  error_commands=$(echo "${rows}" | grep -E '"exit_code"\s*:\s*[1-9][0-9]*' | wc -l | tr -d ' ')
  local total_commands
  total_commands=$(echo "${rows}" | wc -l | tr -d ' ')
  local error_rate=0
  [[ ${total_commands} -gt 0 ]] && error_rate=$(( error_commands * 100 / total_commands ))

  local j
  j="{\"timestamp\":\"$(date +%Y-%m-%dT%H:%M:%S%z)\",\"session_id\":\"${session_id}\",\"pattern_type\":\"command_usage\",\"total_commands\":${total_commands},\"error_rate\":${error_rate}}"
  mkdir -p "$(dirname "${PATTERNS_DB}")"
  echo "${j}" >> "${PATTERNS_DB}"
  log "commands total=${total_commands} error%=${error_rate}"
}

case "${1:-all}" in
  commands) detect_command_patterns "${2:-}" ;;
  all) detect_command_patterns "${2:-}" ;;
  *) echo "Usage: $0 {commands|all} [session_id]"; exit 1;;
esac

log "done"


