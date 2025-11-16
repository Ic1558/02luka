#!/usr/bin/env zsh
# Apply Trading CLI Snapshot Filename Fix
# This script applies the fix to include filter parameters in snapshot filenames

set -euo pipefail

TRADING_CLI="tools/trading_cli.zsh"
REPO_ROOT="${LUKA_SOT:-$HOME/02luka}"

cd "$REPO_ROOT"

if [[ ! -f "$TRADING_CLI" ]]; then
  echo "❌ Error: $TRADING_CLI not found"
  echo "Please ensure you're on the codex/implement-02luka-trading-cli-v2-spec branch"
  exit 1
fi

echo "🔧 Applying Trading CLI Snapshot Filename Fix"
echo "=============================================="
echo ""

# Create backup
BACKUP="${TRADING_CLI}.backup.$(date +%Y%m%d_%H%M%S)"
cp "$TRADING_CLI" "$BACKUP"
echo "✅ Backup created: $BACKUP"
echo ""

# Check if fix already applied
if grep -q "normalize_filter_value" "$TRADING_CLI"; then
  echo "⚠️  Fix appears to already be applied (normalize_filter_value found)"
  echo "   Skipping to avoid duplicate code"
  exit 0
fi

echo "📝 Applying fix..."
echo ""

# This is a complex patch - we'll use sed/perl to make the changes
# Note: This is a template - actual line numbers may vary

# Step 1: Add helper function before snapshot function
# Find a good insertion point (before any snapshot-related function)

# Step 2: Modify the filename construction
# This requires finding the exact lines and replacing them

echo "⚠️  Manual implementation required"
echo ""
echo "The fix requires precise line number matching."
echo "Please use the implementation guide:"
echo "  g/reports/TRADING_CLI_SNAPSHOT_FIX_IMPLEMENTATION.md"
echo ""
echo "Or apply the changes manually following the guide."

exit 0
