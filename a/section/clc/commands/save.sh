#!/usr/bin/env bash
set -euo pipefail

# 3-Layer Save System
# Layer 1: Session file → g/reports/sessions/
# Layer 2: Update 02luka.md "Last Session" marker
# Layer 3: Append summary to CLAUDE_MEMORY_SYSTEM.md

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
AGENT="${AGENT:-clc}"
TS="$(date +%y%m%d_%H%M%S)"
TITLE="${1:-note}"
SLUG="$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//;s/-$//')"

# === Layer 1: Session File ===
SESSION_DIR="$ROOT/g/reports/sessions"
mkdir -p "$SESSION_DIR"
SESSION_FILE="$SESSION_DIR/session_${TS}_${SLUG}.md"

{
  echo "# $TITLE"
  echo
  echo "- Agent: $AGENT"
  echo "- Created: $(date -Iseconds)"
  echo "- Session: ${TS}"
  echo
} > "$SESSION_FILE"

echo "✅ Layer 1: $SESSION_FILE"

# === Layer 2: Update 02luka.md ===
CONTEXT_FILE="$ROOT/02luka.md"
if [[ -f "$CONTEXT_FILE" ]]; then
  if grep -q "^Last Session:" "$CONTEXT_FILE"; then
    # Update existing marker
    sed -i.bak "s/^Last Session:.*/Last Session: ${TS}/" "$CONTEXT_FILE"
    rm -f "${CONTEXT_FILE}.bak"
    echo "✅ Layer 2: Updated 02luka.md → Last Session: ${TS}"
  else
    # Add marker at end
    echo "" >> "$CONTEXT_FILE"
    echo "Last Session: ${TS}" >> "$CONTEXT_FILE"
    echo "✅ Layer 2: Added marker to 02luka.md → Last Session: ${TS}"
  fi
else
  echo "⚠️  Layer 2: 02luka.md not found, skipping"
fi

# === Layer 3: Append to CLAUDE_MEMORY_SYSTEM.md ===
MEMORY_FILE="$ROOT/CLAUDE_MEMORY_SYSTEM.md"

# Initialize if doesn't exist
if [[ ! -f "$MEMORY_FILE" ]]; then
  cat > "$MEMORY_FILE" <<'HEADER'
# CLAUDE Memory System

Cumulative AI context memory for 02luka system. Each session appends key learnings, decisions, and state changes.

---

HEADER
  echo "✅ Layer 3: Initialized CLAUDE_MEMORY_SYSTEM.md"
fi

# Append session entry
{
  echo "## Session ${TS} - ${TITLE}"
  echo
  echo "**Date:** $(date -Iseconds)"
  echo "**Agent:** ${AGENT}"
  echo "**File:** \`g/reports/sessions/session_${TS}_${SLUG}.md\`"
  echo
  echo "*(Session details recorded in Layer 1 file)*"
  echo
  echo "---"
  echo
} >> "$MEMORY_FILE"

echo "✅ Layer 3: Appended to CLAUDE_MEMORY_SYSTEM.md"
echo ""
echo "📝 3-Layer Save Complete:"
echo "   Layer 1: $SESSION_FILE"
echo "   Layer 2: 02luka.md (Last Session: ${TS})"
echo "   Layer 3: CLAUDE_MEMORY_SYSTEM.md (appended)"
