#!/usr/bin/env zsh
# tools/save.sh
# Save current state + Harvest Active Memory

if [[ -z "${RUN_TOOL_DISPATCH:-}" ]]; then
    echo "❌ ERROR: Direct execution denied."
    echo "   You must use the canonical dispatcher:"
    echo "   zsh tools/run_tool.zsh save"
    exit 1
fi

REPO_ROOT="${REPO_ROOT:-$HOME/02luka}"
zsh "$REPO_ROOT/tools/solution_collector.zsh" 2>/dev/null & # Background harvest Save System
# Forwards requests to backend (session_save.zsh) with telemetry context.

set -e

# Phase 11: SSOT Truth Sync (default ON). Use --no-truth-sync to bypass.
NO_TRUTH_SYNC=0
for arg in "$@"; do
  [[ "$arg" == "--no-truth-sync" ]] && NO_TRUTH_SYNC=1
done
if [[ "$NO_TRUTH_SYNC" -eq 0 ]]; then
  RR="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || echo .)}"
  if [[ -x "$RR/tools/sync_truth.zsh" ]]; then
    zsh "$RR/tools/sync_truth.zsh"
  else
    echo "ERROR: tools/sync_truth.zsh missing or not executable" >&2
    exit 2
  fi
fi

# Resolve paths
SCRIPT_DIR=$(dirname "$0")
BACKEND_SCRIPT="$SCRIPT_DIR/session_save.zsh"

atomic_write_file() {
    local dest="$1"
    local content="$2"
    local dest_dir
    dest_dir=$(dirname "$dest")
    mkdir -p "$dest_dir" || return 1
    local tmp_file
    tmp_file=$(mktemp "${dest_dir}/.save_tmp.XXXXXX") || return 1
    printf '%s\n' "$content" > "$tmp_file" || {
        rm -f "$tmp_file"
        return 1
    }
    if [[ ! -s "$tmp_file" ]]; then
        rm -f "$tmp_file"
        return 1
    fi
    if ! mv -f "$tmp_file" "$dest"; then
        rm -f "$tmp_file"
        return 1
    fi
}

# Load agent context (Phase 1A: Multi-Agent Coordination)
if [[ -f "$SCRIPT_DIR/agent_context.zsh" ]]; then
    source "$SCRIPT_DIR/agent_context.zsh"
else
    # Fallback if agent_context.zsh not available
    export AGENT_ID="${AGENT_ID:-unknown}"
    export AGENT_ENV="${AGENT_ENV:-terminal}"
fi

# Set metadata (preserve existing if set)
export SAVE_AGENT="${SAVE_AGENT:-${AGENT_ID}}"
export SAVE_SOURCE="${SAVE_SOURCE:-${AGENT_ENV}}"
export SAVE_TIMESTAMP="${SAVE_TIMESTAMP:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
export SAVE_SCHEMA_VERSION="${SAVE_SCHEMA_VERSION:-1}"

SAVE_META_FILE="${SAVE_META_FILE:-$REPO_ROOT/g/reports/sessions/save_last.txt}"
SAVE_META_CONTENT="ts=${SAVE_TIMESTAMP} agent=${SAVE_AGENT} source=${SAVE_SOURCE}"
if ! atomic_write_file "$SAVE_META_FILE" "$SAVE_META_CONTENT"; then
    echo "⚠️  Failed to write save metadata (ignored): $SAVE_META_FILE"
fi

# --- HARD GATE: Pre-Action Read Stamp (GG Review requirement) ---
# Block if agent hasn't read LIAM.md, session, and telemetry
GATE_SCRIPT="$SCRIPT_DIR/pre_action_gate.zsh"
if [[ -f "$GATE_SCRIPT" ]]; then
  source "$GATE_SCRIPT"
  if ! pre_action_stamp_verify; then
    echo ""
    echo "💡 Run 'read-now' or 'zsh tools/pre_action_gate.zsh create' first"
    exit 1
  fi
fi

# Log intent (optional, for debugging)
# echo "🔹 Agent: ${AGENT_ID} | Env: ${AGENT_ENV} | Source: ${SAVE_SOURCE}"

# Mary Router preflight (report-only)
if [[ -x "$SCRIPT_DIR/mary_preflight.zsh" ]]; then
  echo ""
  echo "▶ Running Mary Router preflight (report-only)..."
  "$SCRIPT_DIR/mary_preflight.zsh" || echo "⚠️ Mary preflight failed (ignored)"
  echo ""
fi

# Pass arguments as topic/summary if provided
# In the legacy save.sh, $1 might be a flag or text.
# For this gateway, we pass args through to the environment or flags expected by session_save.zsh
# But session_save.zsh primarily reads MLS ledger.
# If arguments are provided, we can map them to TELEMETRY_TOPIC or pass them along.

if [[ $# -gt 0 ]]; then
    export TELEMETRY_TOPIC="$*"
fi

# Execute backend
if [[ -f "$BACKEND_SCRIPT" ]]; then
    zsh "$BACKEND_SCRIPT" "$@"
    exit_code=$?
    exit $exit_code
else
    echo "❌ Error: Save backend not found at $BACKEND_SCRIPT"
    exit 1
fi
