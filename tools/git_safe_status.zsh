#!/usr/bin/env zsh
# Git Safe Status Check
# Purpose: Show git status with warnings for missing files from origin/main
# Usage: zsh tools/git_safe_status.zsh

set -euo pipefail

cd ~/02luka

echo "==> Git Status Check (Safe Mode)"
echo

# Fetch quietly
git fetch origin --quiet 2>/dev/null || true

# Show current branch
CURRENT_BRANCH=$(git branch --show-current)
BEHIND=$(git rev-list --count HEAD..origin/main 2>/dev/null || echo "0")
AHEAD=$(git rev-list --count origin/main..HEAD 2>/dev/null || echo "0")

echo "Branch: $CURRENT_BRANCH"
if [[ $BEHIND -gt 0 ]]; then
  echo "⚠️  Behind origin/main by $BEHIND commit(s)"
fi
if [[ $AHEAD -gt 0 ]]; then
  echo "↑ Ahead of origin/main by $AHEAD commit(s)"
fi
echo

# Check for missing tracked files
echo "==> Checking for missing files from origin/main..."
MISSING=0

# Check if we're on main or diverged branch
if [[ "$CURRENT_BRANCH" == "main" ]] && [[ $BEHIND -gt 0 ]]; then
  echo "⚠️  Local main is behind origin/main"
  echo "   Some files may appear 'deleted' in IDE but exist in origin/main"
  echo
  echo "   To restore specific file:"
  echo "     git checkout origin/main -- <file>"
  echo
  echo "   Or use:"
  echo "     zsh tools/git_restore_missing_from_origin.zsh <file>"
  echo
fi

# Show normal git status
echo "==> Git Status:"
git status --short

echo
echo "==> Note: Files marked as 'deleted' in IDE may exist in origin/main"
echo "   Use 'git_restore_missing_from_origin.zsh' to restore them safely"
