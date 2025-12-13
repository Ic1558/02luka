#!/usr/bin/env zsh
# Simple Cursor Chat History Query
# Shows prompts in a readable format
set -euo pipefail

CURSOR_STORAGE="$HOME/Library/Application Support/Cursor/User/workspaceStorage"
WORKSPACE_HASH="${1:-741cf08327b3b44a659383a965967d25}"
DB_FILE="$CURSOR_STORAGE/$WORKSPACE_HASH/state.vscdb"

if [[ ! -f "$DB_FILE" ]]; then
  echo "❌ Database not found: $DB_FILE"
  exit 1
fi

echo "📊 Cursor Chat History"
echo "Workspace: $WORKSPACE_HASH"
echo ""

# Query prompts using SQLite and parse with Python
prompts_data=$(sqlite3 "$DB_FILE" "PRAGMA read_uncommitted=1; SELECT value FROM ItemTable WHERE key = 'aiService.prompts';" 2>/dev/null)

if [[ -z "$prompts_data" ]]; then
  echo "⚠️  No prompts data found"
  exit 0
fi

# Use temp file to avoid heredoc issues with newlines
TMP_FILE=$(mktemp)
echo "$prompts_data" > "$TMP_FILE"

python3 - "$TMP_FILE" <<'PYEOF'
import json, sys, re

with open(sys.argv[1], "r") as f:
    raw = f.read().strip()

# Simple extraction: find all "text":"..." patterns
# This works even with malformed JSON
texts = []
for match in re.finditer(r'"text"\s*:\s*"([^"]*(?:\\.[^"]*)*)"', raw):
    text = match.group(1)
    # Unescape common sequences
    text = text.replace('\\n', '\n').replace('\\"', '"').replace('\\\\', '\\')
    texts.append(text)

# Also try to get commandType if available
cmd_types = []
for match in re.finditer(r'"commandType"\s*:\s*(\d+)', raw):
    cmd_types.append(int(match.group(1)))

if texts:
    print(f"Found {len(texts)} prompt(s):\n")
    for i, text in enumerate(texts, 1):
        cmd_type = cmd_types[i-1] if i-1 < len(cmd_types) else ''
        # Clean up text (truncate long lines)
        text_lines = text.split('\n')
        preview = text_lines[0][:150] if text_lines else text[:150]
        if len(text) > 150 or len(text_lines) > 1:
            preview += "..."
        print(f"{i}. [Type:{cmd_type}] {preview}")
else:
    print("⚠️  Could not extract prompts")
    print(f"Raw data (first 500 chars):\n{raw[:500]}")
PYEOF

rm -f "$TMP_FILE"

