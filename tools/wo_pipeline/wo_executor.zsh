#!/usr/bin/env zsh
# Execute pending WOs (stubbed actions that keep state in sync)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SCRIPT_DIR/lib_wo_common.zsh"

STATE_DIR="$REPO_ROOT/followup/state"

state_value() {
  local file="$1" query="$2"
  jq -r "${query} // \"\"" "$file" 2>/dev/null
}

compute_action() {
  local category="$1"
  local priority="$2"
  local lower="${category:l}"
  case "$lower" in
    *patch*|*apply*) echo "patch-preflight" ;;
    *json*|*parser*|*data*) echo "data-normalize" ;;
    *telemetry*|*health*) echo "telemetry-sync" ;;
    *guardrail*|*audit*) echo "health-check" ;;
    *)
      if [[ "${priority:l}" == "high" ]]; then
        echo "rapid-dispatch"
      else
        echo "tracking-only"
      fi
      ;;
  esac
}

process_state() {
  local state_file="$1"
  local wo_id="$(state_value "$state_file" '.id')"
  local inbox_path="$(state_value "$state_file" '.meta.inbox_path')"
  local category="$(state_value "$state_file" '.category')"
  local priority="$(state_value "$state_file" '.priority')"
  local owner="$(state_value "$state_file" '.owner')"
  local title="$(state_value "$state_file" '.title')"

  if [[ -n "$inbox_path" && ! -f "$inbox_path" ]]; then
    log_warn "wo_executor: source file missing for $wo_id ($inbox_path)"
    update_state_field "$state_file" "last_error" "WO source missing"
    return 1
  fi

  local action
  action="$(compute_action "$category" "$priority")"
  local note="${title:-$wo_id} routed via ${action//_/ } for ${owner:-auto}"

  # AP/IO v3.1 ledger logging (if enabled)
  local LEDGER_HOOK="$REPO_ROOT/tools/hybrid_ledger_hook.zsh"
  local WO_START_TS=$(python3 -c "import time; print(int(time.time() * 1000))" 2>/dev/null || date +%s%3N)
  
  if [[ -z "${HYBRID_LEDGER_DISABLE:-}" ]] && [[ -x "$LEDGER_HOOK" ]]; then
    # Log task_start
    set +e
    "$LEDGER_HOOK" task_start "$wo_id" "WO processing started: $wo_id" \
      "{\"category\":\"$category\",\"priority\":\"$priority\",\"action\":\"$action\"}" \
      "parent-wo-$wo_id" "" 2>/dev/null || true
    set -e
  fi

  # Process WO (update state)
  update_state_field "$state_file" "notes" "$note"
  update_state_field "$state_file" "progress" "100" int
  update_state_field "$state_file" "meta.last_execution_action" "$action"
  update_state_field "$state_file" "meta.last_executor" "wo_executor"
  update_state_field "$state_file" "meta.last_execution" "$(iso_now)"
  update_state_field "$state_file" "last_error" ""
  
  local exec_result=0
  
  # Log task_result
  if [[ -z "${HYBRID_LEDGER_DISABLE:-}" ]] && [[ -x "$LEDGER_HOOK" ]]; then
    local WO_END_TS=$(python3 -c "import time; print(int(time.time() * 1000))" 2>/dev/null || date +%s%3N)
    local EXECUTION_DURATION_MS=$((WO_END_TS - WO_START_TS))
    
    set +e
    "$LEDGER_HOOK" task_result "$wo_id" "WO processing completed: $wo_id" \
      "{\"status\":\"success\",\"action\":\"$action\",\"category\":\"$category\"}" \
      "parent-wo-$wo_id" "$EXECUTION_DURATION_MS" 2>/dev/null || true
    set -e
  fi
  
  return $exec_result
}

main() {
  ensure_dir "$STATE_DIR"
  setopt null_glob

  local file executed=0
  for file in "$STATE_DIR"/*.json(.N); do
    local state_status
    state_status="$(state_value "$file" '.status')"
    [[ "$state_status" == "pending" ]] || continue

    (( ++executed ))
    log_info "wo_executor: running $file"
    mark_status "$file" "running"

    if process_state "$file"; then
      mark_status "$file" "done"
    else
      mark_status "$file" "failed"
    fi
  done

  if (( executed == 0 )); then
    log_info "wo_executor: nothing to run"
  else
    trigger_followup_regen
    log_info "wo_executor: completed $executed work order(s)"
  fi
}

main "$@"
