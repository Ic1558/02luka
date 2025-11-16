#!/usr/bin/env zsh
# CLS Audit with Ledger - Wrapper that writes to both audit and ledger
# Usage: cls_audit_with_ledger.zsh <action> <task_id> <summary> [data_json]
# This replaces direct writes to cls_audit.jsonl and adds ledger integration

set -euo pipefail

REPO_ROOT="${LUKA_SOT:-$HOME/02luka}"
AUDIT_FILE="$REPO_ROOT/g/telemetry/cls_audit.jsonl"
LEDGER_HOOK="$REPO_ROOT/tools/cls_ledger_hook.zsh"

ACTION="${1:-}"
TASK_ID="${2:-unknown}"
SUMMARY="${3:-}"
DATA_JSON="${4:-{}}"

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Write to audit log (existing behavior)
cat >> "$AUDIT_FILE" <<EOF
{"timestamp":"$TIMESTAMP","agent":"CLS","action":"$ACTION","task_id":"$TASK_ID","summary":"$SUMMARY","data":$DATA_JSON}
EOF

# Determine event type from action
case "$ACTION" in
  *start|*begin|*init)
    EVENT_TYPE="task_start"
    ;;
  *complete|*done|*finish|*success|*result)
    EVENT_TYPE="task_result"
    ;;
  *error|*fail|*failure)
    EVENT_TYPE="error"
    ;;
  *info|*log|*note)
    EVENT_TYPE="info"
    ;;
  *)
    EVENT_TYPE="info"
    ;;
esac

# Write to ledger (new behavior)
if [[ -x "$LEDGER_HOOK" ]]; then
  "$LEDGER_HOOK" "$EVENT_TYPE" "$TASK_ID" "$SUMMARY" "$DATA_JSON" 2>/dev/null || {
    echo "Warning: Ledger write failed (non-fatal)" >&2
  }
fi

echo "✅ Audit and ledger updated: $ACTION"
