#!/bin/bash
set -euo pipefail

export LUKA_SOT="${LUKA_SOT:-$HOME/02luka}"
MEM_SYNC="$LUKA_SOT/tools/memory_sync.sh"

# Load shared context
CONTEXT=$("$MEM_SYNC" get 2>/dev/null || echo '{}')

# Extract relevant info for Gemini
AGENTS=$(echo "$CONTEXT" | jq -r '.agents | to_entries[] | "\(.key): \(.value.status)"' 2>/dev/null || echo "none")
WORK=$(echo "$CONTEXT" | jq -r '.current_work' 2>/dev/null || echo "{}")

# Build system prompt
MLS_SECTION="$(
  python3 "$LUKA_SOT/g/tools/mls_cli_prompt.py" --feed "$LUKA_SOT/g/knowledge/mls_lessons_cli.jsonl" --limit 30 2>/dev/null || true
)"
if [[ -n "$MLS_SECTION" ]]; then
  SYSTEM_PROMPT="${MLS_SECTION}"
  SYSTEM_PROMPT+=$'\n\n'
else
  SYSTEM_PROMPT=""
fi
SYSTEM_PROMPT+="You are part of 02luka system.
Active agents: $AGENTS
Current work: $WORK
Please maintain consistency with other agents."

# Run Gemini with context (single call)
{
    echo "$SYSTEM_PROMPT"
    echo ""
    echo "User: $*"
} | gemini-cli "$@" || {
    echo "WARN: gemini-cli failed" >&2
    exit 1
}

# Update memory after execution
"$MEM_SYNC" update gemini active >/dev/null 2>&1 || {
    echo "WARN: memory update failed" >&2
}
