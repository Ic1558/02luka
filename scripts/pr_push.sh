#!/usr/bin/env bash
# Atomic PR helper: commit + push + create PR
set -euo pipefail

BRANCH="${1:-}"
TITLE="${2:-chore: update}"
BODY="${3:-Automated PR}"

if [[ -z "$BRANCH" ]]; then
  echo "Usage: $0 <branch> [title] [body]"
  echo ""
  echo "Example:"
  echo "  $0 docs/update-readme \"docs: update README\" \"Adds installation instructions\""
  exit 2
fi

echo "🌿 Switching to branch: $BRANCH"
git checkout -B "$BRANCH"

echo "📦 Staging changes..."
git add -A

if git diff --cached --quiet; then
  echo "⚠️  No staged changes, skipping commit."
else
  echo "📝 Committing..."
  git commit -m "$TITLE" || true
fi

echo "🚀 Pushing to origin/$BRANCH..."
git push -u origin "$BRANCH"

if command -v gh >/dev/null 2>&1; then
  echo "📬 Creating PR via gh CLI..."
  gh pr create --title "$TITLE" --body "$BODY" || true
else
  echo "💡 gh CLI not found. Open PR manually:"
  echo "👉 https://github.com/Ic1558/02luka/compare/$BRANCH?expand=1"
fi

echo "✅ Done!"
