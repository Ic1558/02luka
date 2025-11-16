#!/usr/bin/env zsh
# GG AP/IO v3.1 Integration (Read-Only)
# Purpose: Integration functions for GG agent (read-only, no writes)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
READER="$REPO_ROOT/tools/ap_io_v31/reader.zsh"
AGENT="gg"

# Query ledger entries (read-only)
ap_io_v31_query() {
  local ledger_file="${1:-}"
  shift
  
  if [ -z "$ledger_file" ]; then
    # Query all agent ledgers
    for agent_dir in "$REPO_ROOT/g/ledger"/*/; do
      if [ -d "$agent_dir" ]; then
        local today_file="$agent_dir/$(date +%Y-%m-%d).jsonl"
        if [ -f "$today_file" ]; then
          "$READER" "$today_file" "$@"
        fi
      fi
    done
  else
    "$READER" "$ledger_file" "$@"
  fi
}

# Get correlation ID (for querying, not writing)
ap_io_v31_correlation_id() {
  "$REPO_ROOT/tools/ap_io_v31/correlation_id.zsh"
}

# Note: GG does not write to ledger (read-only orchestrator)
# Use other agents for writing events

