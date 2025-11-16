#!/usr/bin/env zsh
# Merge Conflict Resolution Helper
# Purpose: Help resolve conflicts in feature/launchagent-validator-final-rebase branch

set -euo pipefail

REPO_ROOT="/Users/icmini/02luka"
cd "$REPO_ROOT"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     Merge Conflict Resolution Helper                          ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Check current branch
CURRENT_BRANCH=$(git branch --show-current)
echo "Current branch: $CURRENT_BRANCH"
echo ""

# Check for conflicts
CONFLICTED_FILES=$(git diff --name-only --diff-filter=U 2>/dev/null || echo "")

if [ -z "$CONFLICTED_FILES" ]; then
  echo "⚠️  No conflicts detected in working directory"
  echo ""
  echo "Checking if conflicts exist in merge/rebase state..."
  
  # Check merge state
  if [ -f .git/MERGE_HEAD ]; then
    echo "📋 Merge in progress"
    CONFLICTED_FILES=$(git diff --name-only --diff-filter=U 2>/dev/null || echo "")
  elif [ -d .git/rebase-apply ] || [ -d .git/rebase-merge ]; then
    echo "📋 Rebase in progress"
    CONFLICTED_FILES=$(git diff --name-only --diff-filter=U 2>/dev/null || echo "")
  fi
fi

if [ -z "$CONFLICTED_FILES" ]; then
  echo ""
  echo "✅ No active conflicts found"
  echo ""
  echo "If you're seeing conflicts on GitHub:"
  echo "1. Pull the latest changes: git pull origin feature/launchagent-validator-final-rebase"
  echo "2. Or merge main into your branch: git merge origin/main"
  echo ""
  exit 0
fi

echo "Conflicted files:"
echo "$CONFLICTED_FILES" | while read -r file; do
  echo "  - $file"
done
echo ""

# Check each conflicted file
for file in $CONFLICTED_FILES; do
  if [ ! -f "$file" ]; then
    echo "⚠️  File not found: $file"
    continue
  fi
  
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Checking: $file"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  # Count conflict markers
  CONFLICT_COUNT=$(grep -c "^<<<<<<< " "$file" 2>/dev/null || echo "0")
  
  if [ "$CONFLICT_COUNT" -eq 0 ]; then
    echo "✅ No conflict markers found (may be resolved)"
  else
    echo "⚠️  Found $CONFLICT_COUNT conflict(s)"
    echo ""
    echo "Conflict locations:"
    grep -n "^<<<<<<< " "$file" | head -5
    echo ""
    echo "To resolve:"
    echo "  1. Open: $file"
    echo "  2. Find conflict markers: <<<<<<<, =======, >>>>>>>"
    echo "  3. Choose version (ours/theirs/manual merge)"
    echo "  4. Remove markers"
    echo "  5. Run: git add $file"
  fi
  echo ""
done

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     Resolution Options                                        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Option 1: Accept our version (current branch)"
echo "  git checkout --ours <file>"
echo "  git add <file>"
echo ""
echo "Option 2: Accept their version (incoming changes)"
echo "  git checkout --theirs <file>"
echo "  git add <file>"
echo ""
echo "Option 3: Manual merge"
echo "  1. Edit file manually"
echo "  2. Remove conflict markers"
echo "  3. Keep desired changes"
echo "  4. git add <file>"
echo ""
echo "After resolving all conflicts:"
echo "  git rebase --continue"
echo "  # or"
echo "  git merge --continue"
echo ""
