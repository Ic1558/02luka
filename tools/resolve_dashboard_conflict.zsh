#!/usr/bin/env zsh
# Resolve Dashboard Conflict Helper
# Purpose: Help resolve merge conflict in dashboard.js

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     Dashboard Conflict Resolution Helper                       ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Check if we're on the right branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
echo "Current branch: $CURRENT_BRANCH"
echo ""

# Check for conflicts
if git diff --check 2>/dev/null | grep -q "conflict"; then
  echo "⚠️  Conflicts detected!"
  echo ""
  echo "Conflicted files:"
  git diff --name-only --diff-filter=U 2>/dev/null || echo "  (checking...)"

  echo ""
  echo "To resolve:"
  echo "1. Open the conflicted file:"
  echo "   code g/apps/dashboard/dashboard.js"
  echo ""
  echo "2. Look for conflict markers:"
  echo "   <<<<<<< HEAD"
  echo "   ======="
  echo "   >>>>>>> codex/add-wo-pipeline-metrics-to-dashboard"
  echo ""
  echo "3. Resolve by:"
  echo "   - Keeping both changes (if in different sections)"
  echo "   - Merging metrics objects"
  echo "   - Removing conflict markers"
  echo ""
  echo "4. After resolving:"
  echo "   git add g/apps/dashboard/dashboard.js"
  echo "   git commit -m 'Resolve conflict: Merge WO pipeline metrics'"
else
  echo "✅ No conflicts detected in working directory"
  echo ""
  echo "To check for conflicts with remote:"
  echo "1. Fetch latest:"
  echo "   git fetch origin"
  echo ""
  echo "2. Try merging:"
  echo "   git merge origin/main"
  echo ""
  echo "3. Or use GitHub CLI:"
  echo "   gh pr checkout 296"
fi

echo ""
echo "For detailed guidance, see:"
echo "  g/reports/system/RESOLVE_DASHBOARD_CONFLICT.md"
echo ""
