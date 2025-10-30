#!/usr/bin/env bash
set -euo pipefail
LOG_FILE="${HOME}/02luka/g/logs/cls_phase3.log"
LEARNING_DB="${HOME}/02luka/memory/cls/learning_db.jsonl"
PATTERNS_DB="${HOME}/02luka/memory/cls/patterns.jsonl"
log(){ mkdir -p "$(dirname "$LOG_FILE")" || true; echo "[$(date +%Y-%m-%dT%H:%M:%S%z)] DETECT $1" >> "$LOG_FILE"; }
detect_command_patterns(){ local sid="${1:-}"
  log "commands session=${sid}"
  [[ -f "$LEARNING_DB" ]] || { log "no learning_db"; return 0; }
  local rows; rows=$(grep 'interaction_type":"command' "$LEARNING_DB" 2>/dev/null | head -200)
  [[ -z "$rows" ]] && { log "no command rows"; return 0; }
  # BUG 1 FIX: match non-zero exit codes (10, 11, ...) correctly
  local err tot rate=0
  err=$(echo "$rows" | grep -E '"exit_code"[[:space:]]*:[[:space:]]*[1-9][0-9]*' | wc -l | tr -d " ")
  tot=$(echo "$rows" | wc -l | tr -d " ")
  [[ $tot -gt 0 ]] && rate=$(( err * 100 / tot ))
  mkdir -p "$(dirname "$PATTERNS_DB")"
  printf "%s\n" "{\"timestamp\":\"$(date +%Y-%m-%dT%H:%M:%S%z)\",\"session_id\":\"$sid\",\"pattern_type\":\"command_usage\",\"total_commands\":$tot,\"error_rate\":$rate}" >> "$PATTERNS_DB"
  log "commands total=$tot error%=$rate"
}
case "${1:-all}" in
  commands) detect_command_patterns "${2:-}" ;;
  all) detect_command_patterns "${2:-}" ;;
  *) echo "Usage: $0 {commands|all} [session_id]"; exit 1;;
esac
log "done"
