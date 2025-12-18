#!/usr/bin/env zsh
# Auto-commit script for 02luka project
# Prevents work loss by committing uncommitted changes periodically
# Run every hour via LaunchAgent
set -euo pipefail

BASE="$HOME/02luka"
cd "$BASE" || exit 1

# Check if there are uncommitted changes
if git diff --quiet && git diff --cached --quiet; then
  echo "[$(date)] ✅ No uncommitted changes"
  exit 0
fi

# Count uncommitted files
CHANGED=$(git status --short | wc -l | tr -d ' ')
if [[ $CHANGED -eq 0 ]]; then
  echo "[$(date)] ✅ No changes to commit"
  exit 0
fi

# Create auto-commit with timestamp
TIMESTAMP=$(TZ=Asia/Bangkok date +"%Y-%m-%d %H:%M:%S %z")
COMMIT_MSG="auto-save: $TIMESTAMP

🤖 Automatically committed by auto_commit.zsh
📊 Files changed: $CHANGED
⏰ Timestamp: $TIMESTAMP

Prevents data loss from uncommitted files.

Files changed:
$(git status --porcelain | head -10)
"

# Stage all changes
git add -A

# Commit (non-fatal)
if git commit -m "$COMMIT_MSG" 2>/dev/null; then
  echo "[$(date)] ✅ Auto-committed $CHANGED file(s)"
  
  # Try to push (non-fatal, optional)
  # Uncomment the next 4 lines to enable auto-push
  # if git push origin HEAD 2>/dev/null; then
  #   echo "[$(date)] ✅ Pushed to remote"
  # else
  #   echo "[$(date)] ⚠️  Push failed (will retry later)"
  # fi
else
  echo "[$(date)] ⚠️  Commit failed (may be empty or already committed)"
  exit 0
fi
