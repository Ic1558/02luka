#!/usr/bin/env zsh
# Git Restore Missing Files from origin/main
# Purpose: Safely restore files that exist in origin/main but missing in local branch
# Usage: zsh tools/git_restore_missing_from_origin.zsh [file1] [file2] ...
#        Or run without args to check all tracked files

set -euo pipefail

cd ~/02luka

# Fetch latest
echo "==> Fetching origin..."
git fetch origin --quiet

# Get current branch
CURRENT_BRANCH=$(git branch --show-current)
echo "==> Current branch: $CURRENT_BRANCH"
echo

# If files specified, restore only those
if [[ $# -gt 0 ]]; then
  echo "==> Restoring specified files from origin/main..."
  for file in "$@"; do
    if git cat-file -e "origin/main:$file" 2>/dev/null; then
      if [[ ! -f "$file" ]]; then
        echo "  ✓ Restoring: $file"
        git checkout origin/main -- "$file" 2>/dev/null || true
      else
        echo "  - Exists: $file"
      fi
    else
      echo "  ✗ Not in origin/main: $file"
    fi
  done
  echo
  echo "==> Done. Check status with: git status"
  exit 0
fi

# Otherwise, check for common missing files
echo "==> Checking for common missing files from origin/main..."
echo

MISSING_FILES=()

# Check known important files
KNOWN_FILES=(
  "g/docs/PERSONA_MODEL_v5.md"
  "personas/GEMINI_PERSONA_v5.md"
  "g/docs/HOWTO_TWO_WORLDS_v2.md"
)

for file in "${KNOWN_FILES[@]}"; do
  if git cat-file -e "origin/main:$file" 2>/dev/null; then
    if [[ ! -f "$file" ]] || ! git ls-files --error-unmatch "$file" >/dev/null 2>&1; then
      MISSING_FILES+=("$file")
      echo "  ✗ Missing: $file (exists in origin/main)"
    fi
  fi
done

if [[ ${#MISSING_FILES[@]} -eq 0 ]]; then
  echo "  ✓ All known files present"
  echo
  echo "==> To check specific files, run:"
  echo "    zsh tools/git_restore_missing_from_origin.zsh <file1> <file2> ..."
  exit 0
fi

echo
echo "==> Found ${#MISSING_FILES[@]} missing file(s)"
echo
read "?Restore these files from origin/main? (y/N): " confirm

if [[ "$confirm" =~ ^[Yy]$ ]]; then
  for file in "${MISSING_FILES[@]}"; do
    echo "  ✓ Restoring: $file"
    git checkout origin/main -- "$file" 2>/dev/null || true
  done
  echo
  echo "==> Done. Files restored."
  echo "==> Check status: git status"
else
  echo "==> Cancelled. No files restored."
  echo "==> To restore manually:"
  for file in "${MISSING_FILES[@]}"; do
    echo "    git checkout origin/main -- $file"
  done
fi
