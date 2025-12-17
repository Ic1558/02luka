#!/usr/bin/env zsh
# Auto-Commit Work in Progress
# Prevents work loss by committing uncommitted changes periodically
set -euo pipefail

BASE="$HOME/02luka"
cd "$BASE"

# Check if there are uncommitted changes
if git diff --quiet && git diff --cached --quiet; then
  echo "✅ No uncommitted changes"
  exit 0
fi

# Count uncommitted files
CHANGED=$(git status --short | wc -l | tr -d ' ')
if [[ $CHANGED -eq 0 ]]; then
  echo "✅ No changes to commit"
  exit 0
fi

# Create WIP commit
TIMESTAMP=$(TZ=Asia/Bangkok date +"%Y-%m-%d %H:%M:%S %z")
COMMIT_MSG="WIP: auto-commit work in progress - $TIMESTAMP

🤖 Auto-committed to prevent work loss
📊 Files changed: $CHANGED
⏰ Timestamp: $TIMESTAMP

This is a work-in-progress commit. Squash before final commit."

# Stage all changes
git add -A

# Commit (non-fatal)
if git commit -m "$COMMIT_MSG" 2>/dev/null; then
  echo "✅ Auto-committed $CHANGED file(s)"
  
  # Try to push (non-fatal)
  if git push origin HEAD 2>/dev/null; then
    echo "✅ Pushed to remote"
  else
    echo "⚠️  Push failed (will retry later)"
  fi
else
  echo "⚠️  Commit failed (may be empty or already committed)"
  exit 0
fi

