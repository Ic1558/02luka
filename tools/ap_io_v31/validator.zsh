#!/usr/bin/env zsh
# AP/IO v3.1 Validator
# Purpose: Validate AP/IO v3.1 protocol messages against schema

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# tools/ap_io_v31 -> tools -> repo root
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCHEMA_FILE="$REPO_ROOT/schemas/ap_io_v31.schema.json"

usage() {
  cat >&2 <<EOF
Usage: $0 <message_file|->

  - If message_file is provided, validate that file
  - If '-' is provided, read from stdin

Example:
  $0 message.json
  echo '{"protocol":"AP/IO",...}' | $0 -
EOF
  exit 1
}

[[ $# -lt 1 ]] && usage

MESSAGE_INPUT="$1"

# Check schema exists
if [ ! -f "$SCHEMA_FILE" ]; then
  echo "❌ Schema file not found: $SCHEMA_FILE" >&2
  exit 1
fi

# Check jq availability
if ! command -v jq >/dev/null 2>&1; then
  echo "❌ jq is required for validation" >&2
  exit 1
fi

# Read message
if [ "$MESSAGE_INPUT" = "-" ]; then
  MESSAGE=$(cat)
else
  if [ ! -f "$MESSAGE_INPUT" ]; then
    echo "❌ Message file not found: $MESSAGE_INPUT" >&2
    exit 1
  fi
  MESSAGE=$(cat "$MESSAGE_INPUT")
fi

# Basic JSON validation
if ! echo "$MESSAGE" | jq empty 2>/dev/null; then
  echo "❌ Invalid JSON" >&2
  exit 1
fi

# Check required fields
REQUIRED_FIELDS=("protocol" "version" "agent" "event")
for field in "${REQUIRED_FIELDS[@]}"; do
  if ! echo "$MESSAGE" | jq -e ".$field" >/dev/null 2>&1; then
    echo "❌ Missing required field: $field" >&2
    exit 1
  fi
done

# Check timestamp (accept both "timestamp" and "ts")
if ! echo "$MESSAGE" | jq -e '.timestamp // .ts' >/dev/null 2>&1; then
  echo "❌ Missing required field: timestamp or ts" >&2
  exit 1
fi

# Check protocol
if [ "$(echo "$MESSAGE" | jq -r '.protocol')" != "AP/IO" ]; then
  echo "❌ Invalid protocol" >&2
  exit 1
fi

# Check version
VERSION=$(echo "$MESSAGE" | jq -r '.version')
if [ "$VERSION" != "3.1" ]; then
  echo "❌ Invalid version: $VERSION (expected 3.1)" >&2
  exit 1
fi

# Check agent
AGENT=$(echo "$MESSAGE" | jq -r '.agent')
VALID_AGENTS=("cls" "andy" "hybrid" "liam" "gg" "kim")
if [[ ! " ${VALID_AGENTS[@]} " =~ " ${AGENT} " ]]; then
  echo "❌ Invalid agent: $AGENT" >&2
  exit 1
fi

# Check event type
EVENT_TYPE=$(echo "$MESSAGE" | jq -r '.event.type')
VALID_EVENTS=("heartbeat" "task_start" "task_result" "error" "info" "routing_request" "correlation_query")
if [[ ! " ${VALID_EVENTS[@]} " =~ " ${EVENT_TYPE} " ]]; then
  echo "❌ Invalid event type: $EVENT_TYPE" >&2
  exit 1
fi

# Validate ledger_id format if present
LEDGER_ID=$(echo "$MESSAGE" | jq -r '.ledger_id // ""')
if [ -n "$LEDGER_ID" ] && [ "$LEDGER_ID" != "null" ]; then
  if ! echo "$LEDGER_ID" | grep -qE '^ledger-[0-9]{8}-[0-9]{6}-[a-z]+-[0-9]+$'; then
    echo "❌ Invalid ledger_id format: $LEDGER_ID" >&2
    exit 1
  fi
fi

# Validate parent_id format if present
PARENT_ID=$(echo "$MESSAGE" | jq -r '.parent_id // ""')
if [ -n "$PARENT_ID" ] && [ "$PARENT_ID" != "null" ]; then
  if ! echo "$PARENT_ID" | grep -qE '^parent-(wo|event|session)-.+$'; then
    echo "❌ Invalid parent_id format: $PARENT_ID" >&2
    exit 1
  fi
fi

# Basic validation passed
echo "✅ Message is valid AP/IO v3.1"
exit 0
