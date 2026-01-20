#!/bin/zsh
set -e

# Configuration
FEATURE_BRANCH="feat/menu-bar-app"
TARGET_BRANCH="main"

echo "🧹 [1/4] Starting Cleanup..."
# Remove temporary test artifacts if they exist
rm -fv tests/test_menu_bar_server.py
rm -fv verify_decoupling.py
rm -fv g/core_state/verify_decoupling.py

echo "🔍 [2/4] Verifying Git Status..."
if [[ -n $(git status --porcelain) ]]; then
    echo "❌ Working directory is dirty. Please commit or stash changes."
    git status
    exit 1
fi

CURRENT=$(git branch --show-current)
if [[ "$CURRENT" != "$FEATURE_BRANCH" ]]; then
    echo "⚠️  You are on '$CURRENT'. Switching to '$FEATURE_BRANCH' to verify readiness..."
    git checkout "$FEATURE_BRANCH"
fi

echo "🚀 [3/4] Preparing Main Branch..."
git checkout "$TARGET_BRANCH"
git pull origin "$TARGET_BRANCH"

echo "🔀 [4/4] Merging Feature..."
# Merge with --no-ff to preserve feature history
git merge --no-ff "$FEATURE_BRANCH" -m "feat(menu-bar): add dashboard, local server, and snapshot integration"

echo "✅ Merge Successful!"
echo "👉 Next: 'git push origin main'"
