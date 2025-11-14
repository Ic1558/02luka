#!/usr/bin/env zsh
# Rollback script for Comprehensive Alert Review Tool deployment
# Generated: 2025-11-12
# Feature: comprehensive_alert_review_tool

set -euo pipefail

REPO="${LUKA_SOT:-$HOME/02luka}"
cd "$REPO"

BACKUP_DIR="$REPO/g/reports/rollbacks/comprehensive_alert_review_tool_20251112"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "=== Rollback: Comprehensive Alert Review Tool ==="
echo "Time: $TIMESTAMP"
echo ""

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Rollback steps
echo "1. Removing deployed tool..."
if [[ -f "$REPO/tools/comprehensive_alert_review.zsh" ]]; then
  mv "$REPO/tools/comprehensive_alert_review.zsh" "$BACKUP_DIR/comprehensive_alert_review.zsh.backup" || true
  echo "   ✅ Tool removed"
else
  echo "   ⚠️  Tool not found (may already be removed)"
fi

echo ""
echo "2. Cleaning up generated reports..."
# Reports can stay (they're read-only outputs)

echo ""
echo "3. Verifying rollback..."
if [[ ! -f "$REPO/tools/comprehensive_alert_review.zsh" ]]; then
  echo "   ✅ Tool successfully removed"
else
  echo "   ⚠️  Tool still exists - manual cleanup may be needed"
fi

echo ""
echo "=== Rollback Complete ==="
echo "Backup location: $BACKUP_DIR"
echo ""
echo "To restore:"
echo "  cp $BACKUP_DIR/comprehensive_alert_review.zsh.backup $REPO/tools/comprehensive_alert_review.zsh"
echo "  chmod +x $REPO/tools/comprehensive_alert_review.zsh"

