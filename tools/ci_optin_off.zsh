#!/usr/bin/env zsh
set -euo pipefail

pr_num="${1:?PR number required}"

echo "🔒 Disabling opt-in smoke for PR #$pr_num..."

# Try gh CLI first
if command -v gh >/dev/null 2>&1; then
  if gh pr edit "$pr_num" --remove-label run-smoke 2>/dev/null; then
    echo "✅ Removed label 'run-smoke' from PR #$pr_num"
    exit 0
  fi
fi

# Fallback: Puppeteer (would need remove-label support)
echo "⚠️  Label removal via Puppeteer not yet implemented"
echo "💡 Manual: Remove 'run-smoke' label from PR #$pr_num in GitHub UI"
exit 1

