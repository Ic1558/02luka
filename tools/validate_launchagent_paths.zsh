#!/usr/bin/env zsh
# LaunchAgent Path Validator
# Purpose: Pre-commit hook to validate LaunchAgent plists reference existing files
# Created: 2025-11-17
# Usage: Run as pre-commit hook or manually

set -euo pipefail

ERRORS=0
WARNINGS=0
REPORT_FILE="/tmp/launchagent_validation_$(date +%Y%m%d_%H%M%S).txt"

echo "🔍 Validating LaunchAgent Paths..." > "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Function to extract script path from plist
extract_script_path() {
  local plist="$1"
  # Extract ProgramArguments and find the script path
  /usr/libexec/PlistBuddy -c "Print :ProgramArguments" "$plist" 2>/dev/null | \
    grep -E "\.zsh|\.cjs|\.js|\.py|\.sh" | \
    sed 's/^\s*//' | \
    sed "s|\$HOME|$HOME|g" | \
    head -1
}

# Check all com.02luka LaunchAgent plists
for plist in ~/Library/LaunchAgents/com.02luka.*.plist ~/02luka/LaunchAgents/*.plist; do
  [[ -f "$plist" ]] || continue

  agent_name=$(basename "$plist" .plist)
  script_path=$(extract_script_path "$plist")

  if [[ -z "$script_path" ]]; then
    continue
  fi

  # Check if script exists
  if [[ ! -f "$script_path" ]]; then
    echo "❌ ERROR: $agent_name" >> "$REPORT_FILE"
    echo "   Expected: $script_path" >> "$REPORT_FILE"
    echo "   Status: FILE NOT FOUND" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    ERRORS=$((ERRORS + 1))
  fi

  # Check if using old paths (warning only)
  if echo "$script_path" | grep -q "/02luka/tools/" && ! echo "$script_path" | grep -q "/g/tools/"; then
    echo "⚠️  WARNING: $agent_name" >> "$REPORT_FILE"
    echo "   Path: $script_path" >> "$REPORT_FILE"
    echo "   Issue: Using old tools/ path (should be g/tools/)" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    WARNINGS=$((WARNINGS + 1))
  fi

  if echo "$script_path" | grep -q "/02luka/run/" && ! echo "$script_path" | grep -q "/g/run/"; then
    echo "⚠️  WARNING: $agent_name" >> "$REPORT_FILE"
    echo "   Path: $script_path" >> "$REPORT_FILE"
    echo "   Issue: Using old run/ path (should be g/run/)" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    WARNINGS=$((WARNINGS + 1))
  fi
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> "$REPORT_FILE"
echo "Validation Summary:" >> "$REPORT_FILE"
echo "- Errors: $ERRORS" >> "$REPORT_FILE"
echo "- Warnings: $WARNINGS" >> "$REPORT_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> "$REPORT_FILE"

# Print report
cat "$REPORT_FILE"

# Exit with error if any issues found
if [[ $ERRORS -gt 0 ]]; then
  echo ""
  echo "⛔ Validation failed: $ERRORS errors found"
  echo "💡 Fix LaunchAgent paths before committing"
  exit 1
fi

if [[ $WARNINGS -gt 0 ]]; then
  echo ""
  echo "⚠️  Validation warnings: $WARNINGS issues found"
fi

echo ""
echo "✅ LaunchAgent path validation passed"
exit 0
