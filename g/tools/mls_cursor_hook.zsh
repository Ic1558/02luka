#!/usr/bin/env zsh
# MLS Cursor Hook - Auto-capture conversations/prompts
# This should be called after Cursor conversations or integrated into Cursor workflow
set -euo pipefail

BASE="$HOME/02luka"
LEDGER_DIR="$BASE/mls/ledger"
CURSOR_STORAGE="$HOME/Library/Application Support/Cursor/User/workspaceStorage"

# Function to record conversation/prompt
mls_record_conversation() {
  local prompt="$1"
  local response="${2:-}"
  local context="${3:-cursor}"
  
  local title="Cursor Conversation"
  local summary="Prompt: ${prompt:0:200}..."
  [[ -n "$response" ]] && summary="${summary}\nResponse: ${response:0:200}..."
  
  if [[ -f "$BASE/tools/mls_auto_record.zsh" ]]; then
    "$BASE/tools/mls_auto_record.zsh" \
      "learning" \
      "$title" \
      "$summary" \
      "cursor,conversation,prompt,training" \
      "" 2>/dev/null || true
  fi
}

# Function to extract recent conversations from Cursor storage
extract_cursor_conversations() {
  # Check if SQLite database exists
  local db_file=$(find "$CURSOR_STORAGE" -name "state.vscdb" -type f 2>/dev/null | head -1)
  
  if [[ -z "$db_file" ]] || ! command -v sqlite3 >/dev/null 2>&1; then
    echo "⚠️  Cursor storage not accessible or sqlite3 not available"
    return 1
  fi
  
  # Try to extract conversations (this is exploratory - schema may vary)
  sqlite3 "$db_file" "SELECT * FROM ItemTable WHERE key LIKE '%chat%' OR key LIKE '%conversation%' LIMIT 10;" 2>/dev/null || {
    echo "⚠️  Could not query Cursor database (schema may differ)"
    return 1
  }
}

# Main: Record current conversation if arguments provided
if [[ $# -ge 1 ]]; then
  mls_record_conversation "$@"
else
  echo "Usage: mls_cursor_hook.zsh <prompt> [response] [context]"
  echo ""
  echo "To auto-capture, integrate this into Cursor workflow or call after conversations"
fi
