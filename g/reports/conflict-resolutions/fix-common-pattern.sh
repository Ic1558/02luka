#!/bin/bash
# Resolution script for PRs #208, #207, #206, #204
# Fixes common pattern conflicts: pages.yml + .gitignore

set -eo pipefail

echo "🔧 Conflict Resolution Script - Common Pattern"
echo "For PRs: #208, #207, #206, #204"
echo ""

if [ $# -ne 1 ]; then
    echo "Usage: $0 <branch-name>"
    echo ""
    echo "Example:"
    echo "  $0 claude/phase-19.1-gc-hardening"
    echo ""
    echo "Available branches:"
    echo "  - claude/phase-19.1-gc-hardening (PR #208)"
    echo "  - claude/phase-19-ci-hygiene-health (PR #207)"
    echo "  - claude/phase-18-ops-sandbox-runner (PR #206)"
    echo "  - claude/phase-16-bus (PR #204)"
    exit 1
fi

BRANCH=$1

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

# Resolve pages.yml - accept origin/main's printf approach
if [ -f .github/workflows/pages.yml ]; then
    echo "  📝 Resolving .github/workflows/pages.yml (accepting printf approach)..."
    git checkout --theirs .github/workflows/pages.yml
    git add .github/workflows/pages.yml
    echo "  ✅ pages.yml resolved"
fi

# Resolve .gitignore - accept origin/main's clean organization
if [ -f .gitignore ]; then
    echo "  📝 Resolving .gitignore (accepting clean organization)..."
    git checkout --theirs .gitignore
    git add .gitignore
    echo "  ✅ .gitignore resolved"
fi

# Check if there are any remaining conflicts
if git diff --check --cached 2>/dev/null | grep -q "conflict"; then
    echo "⚠️  Additional conflicts remain - manual review required"
    git status
    exit 1
fi

# Commit the resolution
echo "💾 Committing resolution..."
git commit -m "Resolve conflicts: accept printf approach and clean .gitignore

- Accept origin/main's printf implementation for pages.yml (more reliable in CI)
- Accept origin/main's clean .gitignore organization (eliminates duplicates)

Resolves conflicts with PR #209 (pages heredoc fix) and PR #210 (.gitignore cleanup)"

echo ""
echo "✅ Resolution complete!"
echo ""
echo "Next steps:"
echo "1. Review the changes: git show"
echo "2. Run tests: ./scripts/smoke.sh"
echo "3. Push to origin: git push -u origin $BRANCH"
