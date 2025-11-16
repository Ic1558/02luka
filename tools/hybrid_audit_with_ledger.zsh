#!/usr/bin/env zsh
# Hybrid Audit with Ledger - Wrapper for Hybrid/CLI operations
# Usage: hybrid_audit_with_ledger.zsh <action> <task_id> <summary> [data_json]

set -euo pipefail

REPO_ROOT="${LUKA_SOT:-$HOME/02luka}"
LEDGER_HOOK="$REPO_ROOT/tools/hybrid_ledger_hook.zsh"

ACTION="${1:-}"
TASK_ID="${2:-unknown}"
SUMMARY="${3:-}"
DATA_JSON="${4:-{}}"

# Determine event type from action
case "$ACTION" in
  *start|*begin|*init|*execute)
    EVENT_TYPE="task_start"
    ;;
  *complete|*done|*finish|*success|*result)
    EVENT_TYPE="task_result"
    ;;
  *error|*fail|*failure)
    EVENT_TYPE="error"
    ;;
  *)
    EVENT_TYPE="info"
    ;;
esac

# Write to ledger
if [[ -x "$LEDGER_HOOK" ]]; then
  "$LEDGER_HOOK" "$EVENT_TYPE" "$TASK_ID" "$SUMMARY" "$DATA_JSON" 2>/dev/null || {
    echo "Warning: Ledger write failed (non-fatal)" >&2
  }
fi

echo "✅ Hybrid ledger updated: $ACTION"
