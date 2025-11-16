#!/usr/bin/env zsh
# Resolve Trading Snapshot Conflicts
# Helper script to resolve merge conflicts in trading_snapshot.zsh

set -euo pipefail

REPO_ROOT="${LUKA_SOT:-$HOME/02luka}"
cd "$REPO_ROOT"

echo "🔧 Resolving Trading Snapshot Conflicts"
echo "======================================"
echo ""

# Check if we're on the right branch
CURRENT_BRANCH=$(git branch --show-current)
if [[ "$CURRENT_BRANCH" != "codex/fix-trading-cli-snapshot-naming-issue" ]]; then
  echo "⚠️  Current branch: $CURRENT_BRANCH"
  echo "   Expected: codex/fix-trading-cli-snapshot-naming-issue"
  echo ""
  echo "To checkout the branch:"
  echo "  git checkout codex/fix-trading-cli-snapshot-naming-issue"
  exit 1
fi

# Find conflicted files
CONFLICTED=$(git diff --name-only --diff-filter=U 2>/dev/null || echo "")

if [[ -z "$CONFLICTED" ]]; then
  echo "✅ No conflicts found"
  echo ""
  echo "Checking for conflict markers in files..."
  CONFLICT_FILES=$(find . -name "*.zsh" -type f -exec grep -l "<<<<<<< HEAD" {} \; 2>/dev/null || echo "")
  
  if [[ -n "$CONFLICT_FILES" ]]; then
    echo "⚠️  Found conflict markers in:"
    echo "$CONFLICT_FILES"
  else
    echo "✅ No conflict markers found"
  fi
  exit 0
fi

echo "📋 Conflicted files:"
echo "$CONFLICTED"
echo ""

# Check for trading_snapshot.zsh
if echo "$CONFLICTED" | grep -q "trading_snapshot.zsh"; then
  echo "📝 Found conflict in tools/trading_snapshot.zsh"
  echo ""
  echo "To resolve manually:"
  echo "  1. Open tools/trading_snapshot.zsh"
  echo "  2. Look for conflict markers: <<<<<<< HEAD"
  echo "  3. Choose the correct version or merge both"
  echo "  4. Remove conflict markers"
  echo "  5. Run: git add tools/trading_snapshot.zsh"
  echo "  6. Run: git commit"
  echo ""
  echo "See implementation guide:"
  echo "  g/reports/TRADING_CLI_SNAPSHOT_FIX_IMPLEMENTATION.md"
fi
