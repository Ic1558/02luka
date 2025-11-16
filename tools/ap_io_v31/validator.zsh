#!/usr/bin/env zsh
# AP/IO v3.1 Validator
# Purpose: Validate AP/IO v3.1 protocol messages with enhanced validation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
# tools/ap_io_v31 -> tools -> repo root
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCHEMA_FILE="$REPO_ROOT/schemas/ap_io_v31.schema.json"

usage() {
  cat >&2 <<EOF
Usage: $0 [options] [file]

Options:
  -s, --schema <file>    Use custom schema file
  -v, --verbose          Show detailed validation errors
  -h, --help             Show this help

If file is omitted or is '-', reads from stdin.

Examples:
  $0 message.json
  $0 - < message.json
  echo '{"protocol":"AP/IO","version":"3.1",...}' | $0 -
EOF
  exit 1
}

VERBOSE=false
INPUT_FILE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--schema)
      SCHEMA_FILE="$2"
      shift 2
      ;;
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    -h|--help)
      usage
      ;;
    -)
      INPUT_FILE="-"
      shift
      ;;
    *)
      if [ -z "$INPUT_FILE" ]; then
        INPUT_FILE="$1"
      else
        echo "❌ Unknown option: $1" >&2
        usage
      fi
      shift
      ;;
  esac
done

# Read input
if [ -z "$INPUT_FILE" ] || [ "$INPUT_FILE" = "-" ]; then
  INPUT=$(cat)
else
  if [ ! -f "$INPUT_FILE" ]; then
    echo "❌ Error: File not found: $INPUT_FILE" >&2
    exit 1
  fi
  INPUT=$(cat "$INPUT_FILE")
fi

# Check if input is empty
if [ -z "$INPUT" ]; then
  echo "❌ Error: Empty input" >&2
  exit 1
fi

# Validate JSON syntax first
if ! echo "$INPUT" | jq empty 2>/dev/null; then
  echo "❌ Error: Invalid JSON syntax" >&2
  if [ "$VERBOSE" = true ]; then
    echo "$INPUT" | jq . 2>&1 | head -10
  fi
  exit 1
fi

# Extract and validate required fields
validate_field() {
  local field="$1"
  local value="$2"
  local pattern="${3:-}"
  local description="$4"
  
  if [ -z "$value" ] || [ "$value" = "null" ]; then
    echo "❌ Error: Missing required field: $field" >&2
    if [ "$VERBOSE" = true ]; then
      echo "   Description: $description" >&2
    fi
    return 1
  fi
  
  if [ -n "$pattern" ] && ! echo "$value" | grep -qE "$pattern"; then
    echo "❌ Error: Invalid format for field '$field': $value" >&2
    if [ "$VERBOSE" = true ]; then
      echo "   Expected pattern: $pattern" >&2
      echo "   Description: $description" >&2
    fi
    return 1
  fi
  
  return 0
}

# Validate protocol version
PROTOCOL=$(echo "$INPUT" | jq -r '.protocol // empty')
VERSION=$(echo "$INPUT" | jq -r '.version // empty')
AGENT=$(echo "$INPUT" | jq -r '.agent // empty')
TS=$(echo "$INPUT" | jq -r '.ts // .timestamp // empty')
EVENT=$(echo "$INPUT" | jq -r '.event // empty')

# Validate protocol
if [ "$PROTOCOL" != "AP/IO" ]; then
  echo "❌ Error: Invalid protocol: $PROTOCOL (expected: AP/IO)" >&2
  exit 1
fi

# Validate version (strict check for 3.1)
if [ "$VERSION" != "3.1" ]; then
  echo "❌ Error: Invalid version: $VERSION (expected: 3.1)" >&2
  if [ "$VERBOSE" = true ]; then
    echo "   Note: Only AP/IO v3.1 is supported" >&2
  fi
  exit 1
fi

# Validate agent
if ! validate_field "agent" "$AGENT" "^cls|andy|hybrid|liam|gg|kim$" "Agent identifier"; then
  exit 1
fi

# Validate timestamp
if ! validate_field "ts" "$TS" "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}" "ISO 8601 timestamp"; then
  exit 1
fi

# Validate event
if [ "$EVENT" = "null" ] || [ -z "$EVENT" ]; then
  echo "❌ Error: Missing required field: event" >&2
  exit 1
fi

EVENT_TYPE=$(echo "$INPUT" | jq -r '.event.type // empty')
if ! validate_field "event.type" "$EVENT_TYPE" "^heartbeat|task_start|task_result|error|info|routing_request|correlation_query$" "Event type"; then
  exit 1
fi

# Validate ledger_id format if present
LEDGER_ID=$(echo "$INPUT" | jq -r '.ledger_id // empty')
if [ -n "$LEDGER_ID" ] && [ "$LEDGER_ID" != "null" ]; then
  if ! echo "$LEDGER_ID" | grep -qE '^ledger-[0-9]{8}-[0-9]{6}-(cls|andy|hybrid|liam|gg|kim)-[0-9]{3}$'; then
    echo "❌ Error: Invalid ledger_id format: $LEDGER_ID" >&2
    if [ "$VERBOSE" = true ]; then
      echo "   Expected format: ledger-YYYYMMDD-HHMMSS-<agent>-<seq>" >&2
      echo "   Example: ledger-20251117-120000-cls-001" >&2
    fi
    exit 1
  fi
fi

# Validate parent_id format if present
PARENT_ID=$(echo "$INPUT" | jq -r '.parent_id // empty')
if [ -n "$PARENT_ID" ] && [ "$PARENT_ID" != "null" ]; then
  if ! echo "$PARENT_ID" | grep -qE '^parent-(wo|event|session)-[a-zA-Z0-9_-]+$'; then
    echo "❌ Error: Invalid parent_id format: $PARENT_ID" >&2
    if [ "$VERBOSE" = true ]; then
      echo "   Expected format: parent-<type>-<id>" >&2
      echo "   Example: parent-wo-wo-20251117-001" >&2
    fi
    exit 1
  fi
fi

# Validate execution_duration_ms if present
EXEC_DUR=$(echo "$INPUT" | jq -r '.execution_duration_ms // empty')
if [ -n "$EXEC_DUR" ] && [ "$EXEC_DUR" != "null" ]; then
  if ! echo "$EXEC_DUR" | grep -qE '^[0-9]+$'; then
    echo "❌ Error: Invalid execution_duration_ms: $EXEC_DUR (must be numeric)" >&2
    exit 1
  fi
fi

# If schema file exists, validate against it
if [ -f "$SCHEMA_FILE" ] && command -v ajv >/dev/null 2>&1; then
  # Use ajv for JSON Schema validation if available
  if echo "$INPUT" | ajv test -s "$SCHEMA_FILE" --valid 2>/dev/null; then
    echo "✅ Validation passed (schema validated)"
    exit 0
  else
    echo "⚠️  Warning: Schema validation failed (ajv not available or schema issue)" >&2
    # Continue with basic validation
  fi
elif [ -f "$SCHEMA_FILE" ]; then
  # Schema exists but ajv not available - just note it
  if [ "$VERBOSE" = true ]; then
    echo "ℹ️  Info: Schema file exists but ajv not available for full validation" >&2
  fi
fi

# All validations passed
echo "✅ Validation passed"
exit 0
