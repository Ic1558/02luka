#!/usr/bin/env zsh
# @raycast.schemaVersion 1
# @raycast.title ATG Copy Walkthrough
# @raycast.mode silent
# @raycast.packageName 02luka
# @raycast.icon 📘
# @raycast.description Finds latest walkthrough.md and copies to clipboard
# @raycast.needsConfirmation false

set -euo pipefail

# Find the latest modified walkthrough.md in ~/.gemini/antigravity/brain
# 1. find all 'walkthrough.md' files
# 2. sort by modification time (ls -t)
# 3. take top one (head -1)
LATEST_WALKTHROUGH=$(find ~/.gemini/antigravity/brain -name "walkthrough.md" -print0 | xargs -0 ls -t | head -1)

if [[ -n "$LATEST_WALKTHROUGH" && -f "$LATEST_WALKTHROUGH" ]]; then
  cat "$LATEST_WALKTHROUGH" | pbcopy
  # Show parent folder name (session ID) for context
  SESSION_ID=$(basename "$(dirname "$LATEST_WALKTHROUGH")")
  echo "✓ Copied walkthrough ($SESSION_ID)"
else
  echo "❌ No walkthrough.md found in ~/.gemini"
  exit 1
fi
