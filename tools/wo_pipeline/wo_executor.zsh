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

  update_state_field "$state_file" "notes" "$note"
  update_state_field "$state_file" "progress" "100" int
  update_state_field "$state_file" "meta.last_execution_action" "$action"
  update_state_field "$state_file" "meta.last_executor" "wo_executor"
  update_state_field "$state_file" "meta.last_execution" "$(iso_now)"
  update_state_field "$state_file" "last_error" ""
  return 0
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
