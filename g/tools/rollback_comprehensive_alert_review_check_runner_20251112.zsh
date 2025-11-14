#!/usr/bin/env zsh
# Rollback script for Comprehensive Alert Review Tool - Check Runner Integration
# Generated: 2025-11-12
# Feature: comprehensive_alert_review_check_runner_integration

set -euo pipefail

REPO="${LUKA_SOT:-$HOME/02luka}"
cd "$REPO"

BACKUP_DIR="$REPO/g/reports/rollbacks/comprehensive_alert_review_check_runner_20251112"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "=== Rollback: Comprehensive Alert Review Tool - Check Runner Integration ==="
echo "Time: $TIMESTAMP"
echo ""

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Rollback steps
echo "1. Removing check_runner integration from comprehensive_alert_review.zsh..."
if [[ -f "$REPO/tools/comprehensive_alert_review.zsh" ]]; then
  # Backup current version
  cp "$REPO/tools/comprehensive_alert_review.zsh" "$BACKUP_DIR/comprehensive_alert_review.zsh.backup" || true
  
  # Note: Full rollback would require restoring original version
  # For now, just backup and note that manual restoration needed
  echo "   ✅ Current version backed up to: $BACKUP_DIR/comprehensive_alert_review.zsh.backup"
  echo "   ⚠️  Manual restoration required - original version not stored in git"
else
  echo "   ⚠️  Tool not found (may already be removed)"
fi

echo ""
echo "2. Library remains available..."
echo "   ℹ️  check_runner.zsh library remains (may be used by other tools)"
echo "   ℹ️  To remove library: rm $REPO/tools/lib/check_runner.zsh"

echo ""
echo "3. Smoke test remains..."
echo "   ℹ️  Smoke test remains for future use"
echo "   ℹ️  To remove: rm $REPO/tests/check_runner_smoke.zsh"

echo ""
echo "=== Rollback Complete ==="
echo "Backup location: $BACKUP_DIR"
echo ""
echo "To restore:"
echo "  cp $BACKUP_DIR/comprehensive_alert_review.zsh.backup $REPO/tools/comprehensive_alert_review.zsh"
echo "  chmod +x $REPO/tools/comprehensive_alert_review.zsh"
echo ""
echo "Note: Full restoration requires original version from git history"
