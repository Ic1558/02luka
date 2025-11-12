#!/usr/bin/env zsh
# Ensure Remote Sync - Check and push local commits
# Prevents work loss by ensuring local commits are pushed to remote
set -euo pipefail

BASE="$HOME/02luka"
cd "$BASE"

# Check if we're ahead of remote
LOCAL_COMMITS=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo "0")
REMOTE_COMMITS=$(git rev-list --count HEAD..@{u} 2>/dev/null || echo "0")

if [[ $LOCAL_COMMITS -gt 0 ]]; then
  echo "⚠️  Local is ahead by $LOCAL_COMMITS commit(s)"
  echo "🔄 Pushing to remote..."
  
  # Push with retry
  attempt=0
  max_attempts=3
  while [[ $attempt -lt $max_attempts ]]; do
    if git push origin HEAD; then
      echo "✅ Pushed $LOCAL_COMMITS commit(s) to remote"
      exit 0
    fi
    ((attempt++))
    echo "⚠️  Push attempt $attempt failed, retrying..."
    sleep 2
    git pull --rebase 2>/dev/null || true
  done
  
  echo "❌ Failed to push after $max_attempts attempts"
  exit 1
fi

if [[ $REMOTE_COMMITS -gt 0 ]]; then
  echo "ℹ️  Remote is ahead by $REMOTE_COMMITS commit(s)"
  echo "🔄 Pulling from remote..."
  git pull --rebase || echo "⚠️  Pull failed"
fi

if [[ $LOCAL_COMMITS -eq 0 ]] && [[ $REMOTE_COMMITS -eq 0 ]]; then
  echo "✅ Local and remote are in sync"
fi

