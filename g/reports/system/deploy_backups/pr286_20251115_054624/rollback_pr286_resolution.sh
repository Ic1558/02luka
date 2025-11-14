#!/usr/bin/env zsh
# Rollback script for PR #286 resolution
# Generated automatically by /02luka/deploy command

set -euo pipefail

echo "=== PR #286 Resolution Rollback ==="
echo ""
echo "⚠️  WARNING: This will restore PR #286 to its original state"
echo ""
read "?Continue with rollback? (yes/no): " confirm
if [[ "$confirm" != "yes" ]]; then
  echo "Rollback cancelled."
  exit 0
fi

echo ""
echo "→ Restoring original PR #286 branch..."
git checkout ai/codex-review-251114
git reset --hard origin/ai/codex-review-251114

echo ""
echo "→ Removing cleanup branch (if exists)..."
git branch -D pr286-cleanup 2>/dev/null || true

echo ""
echo "✅ Rollback complete. PR #286 restored to original state."
echo ""
echo "Note: Backup branch available: backup/pr286-original-*"
