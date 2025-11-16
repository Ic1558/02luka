#!/usr/bin/env zsh
set -euo pipefail

pr_num="${1:?PR number required}"

echo "🔓 Enabling opt-in smoke for PR #$pr_num..."

# Try gh CLI first
if command -v gh >/dev/null 2>&1; then
  if gh pr edit "$pr_num" --add-label run-smoke 2>/dev/null; then
    echo "✅ Added label 'run-smoke' to PR #$pr_num"
    exit 0
  fi
fi

# Fallback: Puppeteer
if [[ -f tools/puppeteer/run.mjs ]]; then
  pr_url="https://github.com/Ic1558/02luka/pull/$pr_num"
  node tools/puppeteer/run.mjs pr-label --url "$pr_url" --label run-smoke
  echo "✅ Added label 'run-smoke' via Puppeteer"
  exit 0
fi

echo "❌ Neither gh CLI nor Puppeteer available"
exit 1

