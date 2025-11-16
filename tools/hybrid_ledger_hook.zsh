#!/usr/bin/env zsh
# Hybrid Ledger Hook - Integration with Hybrid/Luka CLI execution
# Usage: hybrid_ledger_hook.zsh <event_type> <task_id> <summary> [data_json] [parent_id] [execution_duration_ms]
# This is called by Hybrid/Luka CLI tools to write ledger entries
# Now uses AP/IO v3.1 writer for consistency

set -euo pipefail

REPO_ROOT="${LUKA_SOT:-$HOME/02luka}"
WRITER="$REPO_ROOT/tools/ap_io_v31/writer.zsh"
INTEGRATION="$REPO_ROOT/agents/hybrid/ap_io_v31_integration.zsh"

# Default values
AGENT="hybrid"
SOURCE="luka_cli"
TASK_ID="${2:-unknown}"
SUMMARY="${3:-}"
DATA_JSON="${4:-{}}"
PARENT_ID="${5:-}"
EXECUTION_DURATION_MS="${6:-}"

case "${1:-}" in
  task_start)
    EVENT_TYPE="task_start"
    STATE="busy"
    ;;
  task_result)
    EVENT_TYPE="task_result"
    STATE="idle"
    ;;
  error)
    EVENT_TYPE="error"
    STATE="error"
    ;;
  heartbeat)
    EVENT_TYPE="heartbeat"
    STATE="idle"
    ;;
  info)
    EVENT_TYPE="info"
    STATE="idle"
    ;;
  *)
    echo "Usage: hybrid_ledger_hook.zsh <event_type> <task_id> <summary> [data_json]" >&2
    echo "Event types: task_start, task_result, error, heartbeat, info" >&2
    exit 1
    ;;
esac

# Sanitize command data (remove sensitive info)
if [[ "$DATA_JSON" != "{}" ]]; then
  SANITIZED_DATA=$(echo "$DATA_JSON" | python3 <<PY
import json
import sys
import re

try:
    data = json.load(sys.stdin)
    
    # Remove sensitive patterns
    sensitive_patterns = [
        r'password["\']?\s*[:=]\s*["\']?[^"\']+',
        r'token["\']?\s*[:=]\s*["\']?[^"\']+',
        r'api[_-]?key["\']?\s*[:=]\s*["\']?[^"\']+',
        r'secret["\']?\s*[:=]\s*["\']?[^"\']+',
    ]
    
    # Convert to string and sanitize
    data_str = json.dumps(data)
    for pattern in sensitive_patterns:
        data_str = re.sub(pattern, r'\1***REDACTED***', data_str, flags=re.IGNORECASE)
    
    # Truncate long outputs
    if 'stdout' in data and len(str(data['stdout'])) > 1000:
        data['stdout'] = str(data['stdout'])[:1000] + '... (truncated)'
    if 'stderr' in data and len(str(data['stderr'])) > 1000:
        data['stderr'] = str(data['stderr'])[:1000] + '... (truncated)'
    
    print(json.dumps(data))
except:
    print('{}')
PY
  )
  DATA_JSON="$SANITIZED_DATA"
fi

# Write ledger entry using AP/IO v3.1 writer
if [[ -x "$WRITER" ]]; then
  set +e  # Don't fail if ledger write fails
  if [[ -n "$PARENT_ID" ]] && [[ -n "$EXECUTION_DURATION_MS" ]]; then
    "$WRITER" "$AGENT" "$EVENT_TYPE" "$TASK_ID" "$SOURCE" "$SUMMARY" "$DATA_JSON" "$PARENT_ID" "$EXECUTION_DURATION_MS" || {
      echo "⚠️  Hybrid ledger write failed (non-fatal)" >&2
    }
  elif [[ -n "$PARENT_ID" ]]; then
    "$WRITER" "$AGENT" "$EVENT_TYPE" "$TASK_ID" "$SOURCE" "$SUMMARY" "$DATA_JSON" "$PARENT_ID" || {
      echo "⚠️  Hybrid ledger write failed (non-fatal)" >&2
    }
  else
    "$WRITER" "$AGENT" "$EVENT_TYPE" "$TASK_ID" "$SOURCE" "$SUMMARY" "$DATA_JSON" || {
      echo "⚠️  Hybrid ledger write failed (non-fatal)" >&2
    }
  fi
  set -e
else
  echo "⚠️  AP/IO v3.1 writer not found: $WRITER" >&2
fi

# Update status via integration script
if [[ -x "$INTEGRATION" ]]; then
  # Build event JSON for integration script
  EVENT_JSON=$(cat <<EOF
{
  "protocol": "AP/IO",
  "version": "3.1",
  "agent": "$AGENT",
  "event": {
    "type": "$EVENT_TYPE",
    "task_id": "$TASK_ID",
    "source": "$SOURCE",
    "summary": "$SUMMARY"
  },
  "data": $DATA_JSON
}
EOF
  )
  
  echo "$EVENT_JSON" | "$INTEGRATION" normal >/dev/null 2>&1 || true
fi

echo "✅ Hybrid ledger hook executed: $EVENT_TYPE"
