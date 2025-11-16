#!/usr/bin/env zsh
# Hybrid WO Wrapper with AP/IO v3.1 Ledger Integration
# Purpose: Wrap WO execution with AP/IO v3.1 task_start/task_result logging
#
# Usage:
#   tools/hybrid_wo_wrapper.zsh <wo_file_or_id> [--exec <command>] [--args <args>]
#
# Examples:
#   tools/hybrid_wo_wrapper.zsh bridge/inbox/LLM/wo-251116-test.json
#   tools/hybrid_wo_wrapper.zsh wo-251116-test --exec "tools/wo_pipeline/wo_executor.zsh" --args "wo-251116-test"
#
# Environment Variables:
#   LEDGER_BASE_DIR - Override ledger directory (for testing)
#   HYBRID_LEDGER_DISABLE=1 - Disable ledger logging (emergency override)
#   CORRELATION_ID - Reuse existing correlation ID (for nested calls)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WRITER="$REPO_ROOT/tools/ap_io_v31/writer.zsh"
CORRELATION_ID_GEN="$REPO_ROOT/tools/ap_io_v31/correlation_id.zsh"

usage() {
  cat >&2 <<EOF
Usage: $0 <wo_file_or_id> [options]

Arguments:
  wo_file_or_id  - WO file path or WO ID

Options:
  --exec <command>  - Command to execute (default: auto-detect from WO)
  --args <args>      - Arguments to pass to command
  --parent-id <id>   - Parent ID for nested WOs (format: parent-wo-<id>)

Environment:
  LEDGER_BASE_DIR      - Override ledger directory (for testing)
  HYBRID_LEDGER_DISABLE=1 - Disable ledger logging
  CORRELATION_ID       - Reuse existing correlation ID

Examples:
  $0 bridge/inbox/LLM/wo-251116-test.json
  $0 wo-251116-test --exec "tools/wo_pipeline/wo_executor.zsh" --args "wo-251116-test"
EOF
  exit 1
}

# Check if ledger is disabled
if [[ "${HYBRID_LEDGER_DISABLE:-}" == "1" ]]; then
  echo "⚠️  Hybrid ledger logging disabled (HYBRID_LEDGER_DISABLE=1)" >&2
  # Still execute the WO, just skip logging
  if [[ $# -gt 0 ]]; then
    WO_ID="$1"
    shift
    # Execute original command if provided
    if [[ "$1" == "--exec" ]] && [[ $# -ge 2 ]]; then
      shift 2
      exec "$@"
    else
      # Default execution (would need WO pipeline integration)
      echo "⚠️  No execution command provided" >&2
      exit 1
    fi
  fi
  exit 0
fi

# Parse arguments
[[ $# -lt 1 ]] && usage

WO_INPUT="$1"
shift

EXEC_CMD=""
EXEC_ARGS=""
PARENT_ID=""

# Parse options
while [[ $# -gt 0 ]]; do
  case "$1" in
    --exec)
      EXEC_CMD="$2"
      shift 2
      ;;
    --args)
      EXEC_ARGS="$2"
      shift 2
      ;;
    --parent-id)
      PARENT_ID="$2"
      shift 2
      ;;
    *)
      echo "❌ Unknown option: $1" >&2
      usage
      ;;
  esac
done

# Normalize WO ID
normalize_wo_id() {
  local input="$1"
  # If it's a file path, extract basename without extension
  if [[ -f "$input" ]]; then
    basename "$input" | sed 's/\.[^.]*$//'
  else
    # Already an ID, clean it up
    echo "$input" | sed 's/^wo-//' | sed 's/[^a-zA-Z0-9_-]//g' | sed 's/^/wo-/'
  fi
}

WO_ID=$(normalize_wo_id "$WO_INPUT")

# Generate or reuse correlation ID
if [[ -n "${CORRELATION_ID:-}" ]]; then
  CORR_ID="$CORRELATION_ID"
else
  if [[ -f "$CORRELATION_ID_GEN" ]]; then
    CORR_ID=$("$CORRELATION_ID_GEN" 2>/dev/null || echo "corr-$(date +%Y%m%d)-$(printf "%03d" $RANDOM)")
  else
    CORR_ID="corr-$(date +%Y%m%d)-$(printf "%03d" $RANDOM)"
  fi
fi

# Determine parent_id
if [[ -z "$PARENT_ID" ]]; then
  PARENT_ID="parent-wo-$WO_ID"
fi

# Capture start timestamp (milliseconds)
WO_START_TS=$(python3 -c "import time; print(int(time.time() * 1000))" 2>/dev/null || date +%s%3N)

# Write task_start event
if [[ -f "$WRITER" ]]; then
  set +e  # Don't fail WO if ledger write fails
  "$WRITER" hybrid task_start "$WO_ID" "hybrid" "WO started: $WO_ID" \
    "{\"status\":\"started\",\"correlation_id\":\"$CORR_ID\"}" \
    "$PARENT_ID" "" 2>/dev/null || {
    echo "⚠️  Hybrid ledger write failed (non-fatal): task_start" >&2
  }
  set -e
fi

# Determine execution command
if [[ -z "$EXEC_CMD" ]]; then
  # Try to auto-detect from WO file
  if [[ -f "$WO_INPUT" ]]; then
    # Check if it's a JSON file with execution info
    if command -v jq >/dev/null 2>&1 && jq empty "$WO_INPUT" 2>/dev/null; then
      EXEC_CMD=$(jq -r '.exec.command // "tools/wo_pipeline/wo_executor.zsh"' "$WO_INPUT" 2>/dev/null || echo "tools/wo_pipeline/wo_executor.zsh")
      EXEC_ARGS=$(jq -r '.exec.args // "'"$WO_ID"'"' "$WO_INPUT" 2>/dev/null || echo "$WO_ID")
    else
      # Default to WO executor
      EXEC_CMD="tools/wo_pipeline/wo_executor.zsh"
      EXEC_ARGS="$WO_ID"
    fi
  else
    # Default execution
    EXEC_CMD="tools/wo_pipeline/wo_executor.zsh"
    EXEC_ARGS="$WO_ID"
  fi
fi

# Execute WO
EXIT_CODE=0
STDOUT=""
STDERR=""

# Capture stdout/stderr (limit to 1KB each)
if [[ -n "$EXEC_ARGS" ]]; then
  EXEC_OUTPUT=$("$REPO_ROOT/$EXEC_CMD" $EXEC_ARGS 2>&1) || EXIT_CODE=$?
else
  EXEC_OUTPUT=$("$REPO_ROOT/$EXEC_CMD" 2>&1) || EXIT_CODE=$?
fi

# Split output (simple approach: last 50 lines for stdout, stderr if available)
STDOUT=$(echo "$EXEC_OUTPUT" | tail -50 | head -20 | tr '\n' ' ' | cut -c1-1000)
STDERR=""

# Capture end timestamp
WO_END_TS=$(python3 -c "import time; print(int(time.time() * 1000))" 2>/dev/null || date +%s%3N)
EXECUTION_DURATION_MS=$((WO_END_TS - WO_START_TS))

# Determine status
if [[ $EXIT_CODE -eq 0 ]]; then
  STATUS="success"
  EVENT_TYPE="task_result"
else
  STATUS="failure"
  EVENT_TYPE="error"
fi

# Prepare data JSON
DATA_JSON=$(cat <<EOF
{
  "status": "$STATUS",
  "exit_code": $EXIT_CODE,
  "stdout": "$(echo "$STDOUT" | sed 's/"/\\"/g' | head -c 1000)",
  "correlation_id": "$CORR_ID"
}
EOF
)

# Write task_result or error event
if [[ -f "$WRITER" ]]; then
  set +e  # Don't fail WO if ledger write fails
  "$WRITER" hybrid "$EVENT_TYPE" "$WO_ID" "hybrid" "WO completed: $WO_ID (exit: $EXIT_CODE)" \
    "$DATA_JSON" \
    "$PARENT_ID" \
    "$EXECUTION_DURATION_MS" 2>/dev/null || {
    echo "⚠️  Hybrid ledger write failed (non-fatal): $EVENT_TYPE" >&2
  }
  set -e
fi

# Export correlation ID for nested calls
export CORRELATION_ID="$CORR_ID"

# Return original exit code
exit $EXIT_CODE

