#!/usr/bin/env zsh
set -euo pipefail

cd "${0:A:h}/.."
BRANCH="$(git rev-parse --abbrev-ref HEAD)"

echo "== memory pull (branch: $BRANCH) =="

# Stash any uncommitted changes before subtree pull
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "⚠️  Stashing uncommitted changes..."
  git stash push -u -m "Auto-stash before memory sync $(date +%Y%m%d_%H%M%S)"
  STASHED=true
else
  STASHED=false
fi

git fetch memory
git subtree pull --prefix=_memory memory main --squash -m "chore(memory): subtree pull" || {
  if [ "$STASHED" = "true" ]; then
    echo "⚠️  Subtree pull failed, restoring stash..."
    git stash pop 2>/dev/null || true
  fi
  exit 1
}

# Restore stashed changes if any
if [ "$STASHED" = "true" ]; then
  echo "✅ Restoring stashed changes..."
  git stash pop 2>/dev/null || true
fi
