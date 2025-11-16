#!/usr/bin/env zsh
# Ledger Schema Validator
# Usage: ledger_schema_validate.zsh <ledger_file>
# Example: ledger_schema_validate.zsh g/ledger/cls/2025-11-16.jsonl

set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: ledger_schema_validate.zsh <ledger_file>

Validates that all entries in a ledger JSONL file conform to the schema.

Schema requirements:
  - ts: ISO-8601 timestamp (required)
  - agent: string (required)
  - session_id: string (required, format: YYYY-MM-DD_agent_NNN)
  - event: enum (heartbeat, task_start, task_result, error, info)
  - task_id: string (required)
  - source: string (required)
  - summary: string (required)
  - data: object (required)

Examples:
  ledger_schema_validate.zsh g/ledger/cls/2025-11-16.jsonl
USAGE
  exit 1
}

[[ $# -lt 1 ]] && usage

LEDGER_FILE="$1"

if [[ ! -f "$LEDGER_FILE" ]]; then
  echo "Error: Ledger file not found: $LEDGER_FILE" >&2
  exit 1
fi

# Validate each line
LINE_NUM=0
ERRORS=0
VALID_EVENTS=("heartbeat" "task_start" "task_result" "error" "info")

while IFS= read -r line; do
  LINE_NUM=$((LINE_NUM + 1))
  
  # Skip empty lines
  [[ -z "$line" ]] && continue
  
  # Validate JSON
  if ! echo "$line" | python3 -m json.tool >/dev/null 2>&1; then
    echo "❌ Line $LINE_NUM: Invalid JSON" >&2
    ERRORS=$((ERRORS + 1))
    continue
  fi
  
  # Validate required fields
  REQUIRED_FIELDS=("ts" "agent" "session_id" "event" "task_id" "source" "summary" "data")
  for field in "${REQUIRED_FIELDS[@]}"; do
    if ! echo "$line" | python3 -c "import json, sys; d=json.load(sys.stdin); sys.exit(0 if '$field' in d else 1)" 2>/dev/null; then
      echo "❌ Line $LINE_NUM: Missing required field: $field" >&2
      ERRORS=$((ERRORS + 1))
    fi
  done
  
  # Validate event type
  EVENT=$(echo "$line" | python3 -c "import json, sys; print(json.load(sys.stdin).get('event', ''))" 2>/dev/null)
  if [[ -z "$EVENT" ]] || [[ ! " ${VALID_EVENTS[@]} " =~ " ${EVENT} " ]]; then
    echo "❌ Line $LINE_NUM: Invalid event type: $EVENT" >&2
    ERRORS=$((ERRORS + 1))
  fi
  
  # Validate timestamp format (ISO-8601)
  TS=$(echo "$line" | python3 -c "import json, sys; print(json.load(sys.stdin).get('ts', ''))" 2>/dev/null)
  if [[ -z "$TS" ]]; then
    echo "❌ Line $LINE_NUM: Missing timestamp" >&2
    ERRORS=$((ERRORS + 1))
  elif ! python3 -c "from datetime import datetime; datetime.fromisoformat('$TS')" 2>/dev/null; then
    echo "❌ Line $LINE_NUM: Invalid timestamp format: $TS" >&2
    ERRORS=$((ERRORS + 1))
  fi
  
  # Validate session_id format
  SESSION_ID=$(echo "$line" | python3 -c "import json, sys; print(json.load(sys.stdin).get('session_id', ''))" 2>/dev/null)
  if [[ ! "$SESSION_ID" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}_[a-z0-9_-]+_[0-9]{3}$ ]]; then
    echo "❌ Line $LINE_NUM: Invalid session_id format: $SESSION_ID" >&2
    ERRORS=$((ERRORS + 1))
  fi
  
  # Validate data is object
  if ! echo "$line" | python3 -c "import json, sys; d=json.load(sys.stdin); sys.exit(0 if isinstance(d.get('data'), dict) else 1)" 2>/dev/null; then
    echo "❌ Line $LINE_NUM: 'data' field must be an object" >&2
    ERRORS=$((ERRORS + 1))
  fi
  
done < "$LEDGER_FILE"

if [[ $ERRORS -eq 0 ]]; then
  echo "✅ Schema validation passed: $LINE_NUM entries valid"
  exit 0
else
  echo "❌ Schema validation failed: $ERRORS errors found in $LINE_NUM entries" >&2
  exit 1
fi
