#!/usr/bin/env zsh
set -euo pipefail

# Adjusted path for agent environment
REPO="$HOME/02luka"

cd "$REPO"

echo "== repo =="
pwd
echo

echo "== git status (before) =="
git status
echo

echo "== git diff summary =="
git diff --stat || true
echo

echo "== stage all =="
git add -A

echo "== git status (staged) =="
git status
echo

MSG="core: stabilize state before next decision window 🧹"
echo "== commit =="
git commit -m "$MSG"

echo
echo "== git status (after) =="
git status

echo
echo "== latest commit =="
git --no-pager log -1 --oneline
