#!/bin/bash

# Permission guard (CLS)
if [ -f "$HOME/02luka/tools/permission_guard.zsh" ]; then
  # shellcheck disable=SC1090
  source "$HOME/02luka/tools/permission_guard.zsh"
  permission_guard "$0 $@" || exit $?
fi
# PR Management Script
# This script handles merging, re-running checks, rebasing, and monitoring PRs
# Requires: GitHub CLI (gh) to be installed and authenticated

set -euo pipefail

echo "=== Merging PRs with squash ==="
for pr in 182 181 114 113; do
    echo "Merging PR #$pr..."
    gh pr merge $pr --squash --delete-branch || true
done

echo -e "\n=== Re-running checks for PRs ==="
for pr in 123 124 125 126 127 128 129; do
    echo "Re-running checks for PR #$pr..."
    gh pr checks $pr --re-run || true
done

echo -e "\n=== Rebasing PR 169 on main ==="
gh pr checkout 169 && git rebase origin/main && git push --force-with-lease

echo -e "\n=== Watching checks for PR 164 ==="
gh pr checks 164 -w
