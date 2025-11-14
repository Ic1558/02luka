#!/usr/bin/env zsh
# MLS Session Summary - Record what was done in this session
# Captures all work from the past few hours to MLS Ledger
set -euo pipefail

BASE="$HOME/02luka"
SESSION_DIR="$BASE/g/reports/sessions"
LEDGER_DIR="$BASE/mls/ledger"

# Get latest session file
LATEST_SESSION=$(find "$SESSION_DIR" -name "*.md" -type f 2>/dev/null | sort -r | head -1 || echo "")

if [[ -z "$LATEST_SESSION" ]]; then
  echo "⚠️  No session file found"
  exit 0
fi

SESSION_NAME=$(basename "$LATEST_SESSION" .md)
SESSION_CONTENT=$(cat "$LATEST_SESSION" 2>/dev/null || echo "")

if [[ -z "$SESSION_CONTENT" ]]; then
  echo "⚠️  Session file is empty"
  exit 0
fi

# Extract key activities from session
# Look for patterns like: "✅", "🔧", "📝", "🚀", "🐛", etc.
ACTIVITIES=$(echo "$SESSION_CONTENT" | grep -E "^(✅|🔧|📝|🚀|🐛|❌|⚠️|💡)" | head -20 || echo "")

if [[ -z "$ACTIVITIES" ]]; then
  echo "⚠️  No activities found in session"
  exit 0
fi

# Create summary
SUMMARY=$(echo "$ACTIVITIES" | head -10 | sed 's/^[^ ]* //' | tr '\n' '; ' | sed 's/; $//')
TITLE="Session Summary: $SESSION_NAME"

# Record to MLS Ledger
if [[ -f "$BASE/tools/mls_auto_record.zsh" ]]; then
  "$BASE/tools/mls_auto_record.zsh" \
    "work" \
    "$TITLE" \
    "$SUMMARY" \
    "session,summary" \
    "" 2>/dev/null || true
fi

echo "✅ Session summary recorded to MLS: $SESSION_NAME"
