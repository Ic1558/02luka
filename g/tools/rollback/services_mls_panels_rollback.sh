#!/usr/bin/env zsh
# Rollback script for Services & MLS Panels (PR #293)
# Generated: 2025-11-15

set -euo pipefail

REPO_ROOT="${LUKA_SOT:-$HOME/02luka}"
cd "$REPO_ROOT" || exit 1

echo "=== Rolling back Services & MLS Panels ==="
echo ""

# Find backup tag
BACKUP_TAG=$(git tag -l "backup-pre-services-mls-deploy-*" | sort -r | head -1)

if [[ -z "$BACKUP_TAG" ]]; then
  echo "❌ No backup tag found. Cannot rollback automatically."
  echo "   Manual rollback: git revert <commit-hash>"
  exit 1
fi

echo "Found backup tag: $BACKUP_TAG"
echo ""

# Check current state
CURRENT_COMMIT=$(git rev-parse HEAD)
BACKUP_COMMIT=$(git rev-parse "$BACKUP_TAG")

if [[ "$CURRENT_COMMIT" == "$BACKUP_COMMIT" ]]; then
  echo "✅ Already at backup state. No rollback needed."
  exit 0
fi

echo "Current commit: $CURRENT_COMMIT"
echo "Backup commit:  $BACKUP_COMMIT"
echo ""

# Confirm rollback
read -q "CONFIRM?Rollback to $BACKUP_TAG? (y/N): " || exit 1
echo ""

# Perform rollback
echo "→ Resetting to backup state..."
git reset --hard "$BACKUP_TAG"

echo ""
echo "✅ Rollback complete."
echo ""
echo "Next steps:"
echo "  1. Restart dashboard server if needed"
echo "  2. Verify dashboard functionality"
echo "  3. Remove backup tag if rollback is permanent: git tag -d $BACKUP_TAG"
