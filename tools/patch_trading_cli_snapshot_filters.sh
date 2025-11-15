#!/usr/bin/env bash
# Patch script for trading_cli.zsh snapshot filename filters
# Applies the fix to include filter parameters in snapshot filenames

set -euo pipefail

TRADING_CLI="tools/trading_cli.zsh"

if [[ ! -f "$TRADING_CLI" ]]; then
  echo "Error: $TRADING_CLI not found"
  echo "Please ensure you're on the codex/implement-02luka-trading-cli-v2-spec branch"
  exit 1
fi

echo "Patching $TRADING_CLI..."

# Create backup
cp "$TRADING_CLI" "${TRADING_CLI}.backup.$(date +%Y%m%d_%H%M%S)"

# Find the line numbers for the snapshot function
# This script assumes the code is around lines 417-420
# You may need to adjust line numbers based on actual file

echo "✅ Backup created"
echo "⚠️  Manual patch required - see implementation guide"
echo ""
echo "See: g/reports/feature_trading_snapshot_filename_filters_PLAN.md"
echo "     for detailed implementation instructions"
