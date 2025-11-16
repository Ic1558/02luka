#!/bin/bash
# Resolution script for PR #212 - Fix shell loop errors
# Fixes: smoke.sh (accept process substitution from origin/main)

set -eo pipefail

echo "🔧 Conflict Resolution Script - PR #212 (Shell Loop Fixes)"
echo ""

BRANCH="claude/fix-shell-loop-conflicts-011CUsXQHfdv6dRNjbKWYcTt"

echo "🔄 Checking out branch: $BRANCH"
git checkout "$BRANCH" || { echo "❌ Failed to checkout $BRANCH"; exit 1; }

echo "🔄 Fetching latest from origin..."
git fetch origin main

echo "🔄 Merging origin/main..."
if git merge origin/main --no-edit; then
    echo "✅ Clean merge - no conflicts!"
    exit 0
fi

echo "⚠️  Conflicts detected, resolving..."

# Resolve smoke.sh - accept origin/main's process substitution
if [ -f scripts/smoke.sh ]; then
    echo "  📝 Resolving scripts/smoke.sh (accepting process substitution)..."
    git checkout --theirs scripts/smoke.sh
    git add scripts/smoke.sh
    echo "  ✅ smoke.sh resolved"
    echo ""
    echo "  📋 Resolution details:"
    echo "     - Accepted origin/main's process substitution approach"
    echo "     - This avoids subshell issues with pipe-based loops"
    echo "     - Exit codes now propagate correctly"
fi

# Check if there are any remaining conflicts
if git diff --check --cached 2>/dev/null | grep -q "conflict"; then
    echo "⚠️  Additional conflicts remain - manual review required"
    git status
    exit 1
fi

# Commit the resolution
echo "💾 Committing resolution..."
git commit -m "Resolve conflicts: accept process substitution for shell loops

- Accept origin/main's process substitution implementation
- Fixes subshell issues where exit codes don't propagate correctly
- Aligns with PR #211's shell loop improvements

The process substitution pattern (< <(find ...)) is more robust than
pipe-based loops (find | while) because it avoids creating a subshell
where exit statements would only exit the subshell, not the script."

echo ""
echo "✅ Resolution complete!"
echo ""
echo "Next steps:"
echo "1. Review the changes: git show"
echo "2. Run tests: ./scripts/smoke.sh"
echo "3. Push to origin: git push -u origin $BRANCH"
