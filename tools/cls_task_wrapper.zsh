#!/usr/bin/env zsh
# CLS Task Wrapper with Ledger Integration
# Wraps CLS task execution with ledger hooks

set -euo pipefail

REPO_ROOT="${LUKA_SOT:-$HOME/02luka}"
LEDGER_HOOK="$REPO_ROOT/tools/cls_ledger_hook.zsh"
TASK_ID="${1:-unknown}"
TASK_COMMAND="${2:-}"
shift 2 || true
TASK_ARGS=("$@")

if [[ -z "$TASK_COMMAND" ]]; then
  echo "Usage: cls_task_wrapper.zsh <task_id> <command> [args...]" >&2
  exit 1
fi

# Generate task summary from command
TASK_SUMMARY="${TASK_COMMAND} ${TASK_ARGS[*]}"

# Log task start
if [[ -x "$LEDGER_HOOK" ]]; then
  "$LEDGER_HOOK" "task_start" "$TASK_ID" "$TASK_SUMMARY" '{"command":"'$TASK_COMMAND'","args":['$(printf '"%s",' "${TASK_ARGS[@]}" | sed 's/,$//')']}' || true
fi

# Execute task
START_TIME=$(date +%s)
EXIT_CODE=0
ERROR_MSG=""

if eval "$TASK_COMMAND ${TASK_ARGS[*]}" 2>&1; then
  EXIT_CODE=0
else
  EXIT_CODE=$?
  ERROR_MSG="Command failed with exit code $EXIT_CODE"
fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Log task result
if [[ -x "$LEDGER_HOOK" ]]; then
  if [[ $EXIT_CODE -eq 0 ]]; then
    "$LEDGER_HOOK" "task_result" "$TASK_ID" "$TASK_SUMMARY" "{\"status\":\"success\",\"duration_sec\":$DURATION,\"exit_code\":$EXIT_CODE}" || true
  else
    "$LEDGER_HOOK" "error" "$TASK_ID" "$ERROR_MSG" "{\"error\":\"$ERROR_MSG\",\"exit_code\":$EXIT_CODE,\"duration_sec\":$DURATION}" || true
  fi
fi

exit $EXIT_CODE
