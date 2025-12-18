#!/usr/bin/env zsh
# tools/save.sh
# Universal Gateway for 02luka Save System
# Forwards requests to backend (session_save.zsh) with telemetry context.

set -e

# Resolve paths
SCRIPT_DIR=$(dirname "$0")
BACKEND_SCRIPT="$SCRIPT_DIR/session_save.zsh"

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
    exec "$BACKEND_SCRIPT" "$@"
else
    echo "❌ Error: Save backend not found at $BACKEND_SCRIPT"
    exit 1
fi
