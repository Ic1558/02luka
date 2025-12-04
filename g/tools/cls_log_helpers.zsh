#!/usr/bin/env zsh
# CLS logging helper functions for common patterns
# Source this file to get helper functions

CLS_LOG="${CLS_LOG:-$HOME/02luka/g/tools/cls_log.zsh}"

# Helper: Log WO drop
cls_log_wo_drop() {
  local wo_id="$1"
  local target="${2:-CLC}"
  local location="$3"
  "$CLS_LOG" \
    --action "drop_wo" \
    --category "work_order" \
    --status "dropped" \
    --message "Dropped WO: $wo_id to $target" \
    --severity "info" \
    --source "cls_script" || true
}

# Helper: Log WO implementation
cls_log_wo_implement() {
  local wo_id="$1"
  local status="${2:-completed}"
  "$CLS_LOG" \
    --action "wo_implementation_complete" \
    --category "work_order" \
    --status "$status" \
    --message "WO implementation: $wo_id" \
    --severity "info" \
    --source "cls_script" || true
}

# Helper: Log guard operation
cls_log_guard() {
  local action="$1"
  local status="${2:-completed}"
  local message="${3:-Guard operation}"
  "$CLS_LOG" \
    --action "$action" \
    --category "guard" \
    --status "$status" \
    --message "$message" \
    --severity "info" \
    --source "cls_script" || true
}

# Helper: Log SOT modification (with reason)
cls_log_sot_modification() {
  local wo_id="$1"
  local reason="$2"
  local files="$3"
  local details_file
  details_file=$(mktemp)
  jq -n \
    --arg wo "$wo_id" \
    --arg reason "$reason" \
    --arg files "$files" \
    '{wo_id:$wo,reason:$reason,files:($files|split(","))}' > "$details_file"
  "$CLS_LOG" \
    --action "direct_sot_modification" \
    --category "work_order" \
    --status "proceeding" \
    --message "Direct SOT modification: $wo_id ($reason)" \
    --severity "warning" \
    --source "cls_script" \
    --details-file "$details_file" || true
  rm -f "$details_file"
}
