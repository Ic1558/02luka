#!/bin/bash
# Simple LaunchAgent Script Checker
# Validates that all scripts referenced in LaunchAgent plists exist

ERRORS=0

echo "🔍 Checking LaunchAgent script paths..."
echo ""

for plist in ~/Library/LaunchAgents/com.02luka.*.plist; do
  [[ -f "$plist" ]] || continue

  agent=$(basename "$plist" .plist)

  # Extract script paths from plist
  grep -E "\.zsh|\.cjs|\.js|\.py|\.sh" "$plist" | while read -r line; do
    # Clean up the line
    script=$(echo "$line" | sed 's/<[^>]*>//g' | sed 's/^\s*//' | sed "s|\$HOME|$HOME|g")

    # Skip if empty or doesn't look like a path
    [[ -z "$script" ]] && continue
    [[ "$script" =~ ^/ ]] || continue

    # Check if file exists
    if [[ ! -f "$script" ]]; then
      echo "❌ $agent"
      echo "   Missing: $script"
      echo ""
      ERRORS=$((ERRORS + 1))
    fi
  done
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Errors found: $ERRORS"

if [[ $ERRORS -eq 0 ]]; then
  echo "✅ All LaunchAgent scripts exist"
  exit 0
else
  echo "⛔ Some LaunchAgent scripts are missing"
  exit 1
fi
