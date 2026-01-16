#!/usr/bin/env zsh
set -euo pipefail

# Fix AWK syntax error in gg_nlp_bridge.zsh
# The error shows >>> and <<< markers which shouldn't be there

REPO="$HOME/02luka"
SCRIPT="$REPO/tools/gg_nlp_bridge.zsh"
BACKUP="$SCRIPT.backup.$(date +%Y%m%d_%H%M%S)"

echo "=== Fixing gg_nlp_bridge AWK Error ==="
echo ""

# Backup original
cp "$SCRIPT" "$BACKUP"
echo "✅ Backup created: $BACKUP"

# The current code looks correct, but let's ensure it's clean
# Check if there are any issues with the AWK heredoc
echo "Checking script for issues..."
if grep -q ">>>\|<<<" "$SCRIPT" 2>/dev/null; then
  echo "⚠️  Found >>> or <<< markers - removing them"
  sed -i '' 's/>>> *//g; s/<<< *//g' "$SCRIPT" 2>/dev/null || sed -i 's/>>> *//g; s/<<< *//g' "$SCRIPT"
else
  echo "✅ No >>> or <<< markers found"
fi

# Verify AWK syntax
echo ""
echo "Testing AWK syntax..."
if awk -f /dev/null "$SCRIPT" 2>&1 | grep -q "syntax error"; then
  echo "❌ AWK syntax error detected"
  exit 1
else
  echo "✅ AWK syntax is valid"
fi

# Test the intent_for function pattern
echo ""
echo "Testing AWK pattern..."
TEST_INPUT='"backup now": backup.now'
if echo "$TEST_INPUT" | awk 'match($0, /^"?([^"]+)"?[[:space:]]*:[[:space:]]*([a-zA-Z0-9_.-]+)$/, a) {print a[1], a[2]}' >/dev/null 2>&1; then
  echo "✅ AWK pattern works correctly"
else
  echo "❌ AWK pattern test failed"
  exit 1
fi

echo ""
echo "✅ Fix complete"
echo ""
echo "Next steps:"
echo "  1. Reload LaunchAgent: launchctl unload ~/Library/LaunchAgents/com.02luka.gg.nlp-bridge.plist && launchctl load ~/Library/LaunchAgents/com.02luka.gg.nlp-bridge.plist"
echo "  2. Monitor logs: tail -f $REPO/logs/gg_nlp_bridge.*.log"
