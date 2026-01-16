#!/usr/bin/env zsh
set -euo pipefail

# Diagnostic script to find gg_nlp_bridge AWK error

REPO="$HOME/02luka"

echo "=== Diagnosing gg_nlp_bridge AWK Error ==="
echo ""

echo "1. Checking LaunchAgents..."
launchctl list 2>/dev/null | grep -i "gg.*nlp" || echo "  No gg_nlp LaunchAgents found"
echo ""

echo "2. Checking plist files..."
find ~/Library/LaunchAgents -name "*gg*nlp*" -o -name "*nlp*bridge*" 2>/dev/null | while read plist; do
  echo "  Found: $plist"
  echo "  Program: $(/usr/libexec/PlistBuddy -c "Print :ProgramArguments:0" "$plist" 2>/dev/null || echo "N/A")"
  echo "  Script: $(/usr/libexec/PlistBuddy -c "Print :ProgramArguments:1" "$plist" 2>/dev/null || echo "N/A")"
done
echo ""

echo "3. Searching for awk match patterns with >>> or <<<..."
grep -r ">>>.*match\|match.*<<<" "$REPO" --include="*.sh" --include="*.zsh" --include="*.py" 2>/dev/null | head -10 || echo "  No matches found"
echo ""

echo "4. Searching for awk patterns with problematic regex..."
grep -r "match.*\?\?.*\[\[:space:\]\]" "$REPO" --include="*.sh" --include="*.zsh" 2>/dev/null | head -10 || echo "  No matches found"
echo ""

echo "5. Checking recent error logs..."
tail -20 "$REPO/logs/gg_nlp_bridge.20251112_052244.log" 2>/dev/null || echo "  Log file not found"
echo ""

echo "✅ Diagnostic complete"
