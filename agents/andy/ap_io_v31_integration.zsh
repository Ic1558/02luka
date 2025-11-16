#!/usr/bin/env zsh
# Andy AP/IO v3.1 Integration
# Purpose: Integration functions for Andy agent

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
WRITER="$REPO_ROOT/tools/ap_io_v31/writer.zsh"
READER="$REPO_ROOT/tools/ap_io_v31/reader.zsh"
AGENT="andy"

# Log an event
ap_io_v31_log() {
  local event_type="$1"
  local task_id="$2"
  local source="$3"
  local summary="$4"
  local data_json="${5:-{}}"
  local parent_id="${6:-}"
  local execution_duration_ms="${7:-}"
  
  "$WRITER" "$AGENT" "$event_type" "$task_id" "$source" "$summary" "$data_json" "$parent_id" "$execution_duration_ms"
}

# Query ledger entries
ap_io_v31_query() {
  local ledger_file="${1:-$REPO_ROOT/g/ledger/$AGENT/$(date +%Y-%m-%d).jsonl}"
  shift
  
  "$READER" "$ledger_file" "$@"
}

# Route event to other agents
ap_io_v31_route() {
  local event_file="$1"
  local priority="${2:-normal}"
  
  if [ ! -f "$event_file" ]; then
    echo "❌ Error: Event file not found: $event_file" >&2
    return 1
  fi
  
  "$REPO_ROOT/tools/ap_io_v31/router.zsh" "$event_file" --priority "$priority"
}

# Get correlation ID
ap_io_v31_correlation_id() {
  "$REPO_ROOT/tools/ap_io_v31/correlation_id.zsh"
}

