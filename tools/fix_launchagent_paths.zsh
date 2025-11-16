#!/usr/bin/env zsh
# Fix LaunchAgent paths after refactor moved files to g/ subdirectories
# Created: 2025-11-17
# Purpose: Update all com.02luka LaunchAgent plists to use new g/tools/ and g/run/ paths

set -euo pipefail

BACKUP_DIR="$HOME/02luka/LaunchAgents/backups/$(date +%Y%m%d_%H%M%S)"
REPORT_FILE="$HOME/02luka/g/reports/system/launchagent_path_fix_$(date +%Y%m%d_%H%M%S).md"

mkdir -p "$BACKUP_DIR"
mkdir -p "$(dirname "$REPORT_FILE")"

echo "# LaunchAgent Path Fix Report - $(date)" > "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "## Summary" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

fixed_count=0
total_count=0

# Find all com.02luka plists
for plist in ~/Library/LaunchAgents/com.02luka.*.plist; do
  [[ -f "$plist" ]] || continue

  agent_name=$(basename "$plist" .plist)
  total_count=$((total_count + 1))

  # Check if plist references old paths
  if grep -q "/02luka/tools/" "$plist" || grep -q "/02luka/run/" "$plist"; then
    echo "## $agent_name" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"

    # Backup original
    cp "$plist" "$BACKUP_DIR/"
    echo "📦 Backed up: $agent_name"

    # Fix paths
    sed -i.bak \
      -e 's|/02luka/tools/|/02luka/g/tools/|g' \
      -e 's|/02luka/run/|/02luka/g/run/|g' \
      "$plist"

    rm "${plist}.bak"

    # Unload and reload agent
    launchctl unload "$plist" 2>/dev/null || true
    launchctl load "$plist" 2>/dev/null || true

    echo "✅ Fixed: $agent_name"
    echo "- **Status:** Path updated and reloaded" >> "$REPORT_FILE"
    echo "- **Backup:** $BACKUP_DIR/$(basename $plist)" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"

    fixed_count=$((fixed_count + 1))
  fi
done

echo "" >> "$REPORT_FILE"
echo "## Statistics" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "- **Total agents checked:** $total_count" >> "$REPORT_FILE"
echo "- **Agents fixed:** $fixed_count" >> "$REPORT_FILE"
echo "- **Backup location:** $BACKUP_DIR" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ LaunchAgent Path Fix Complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📊 Results:"
echo "  - Total agents: $total_count"
echo "  - Fixed: $fixed_count"
echo "  - Backups: $BACKUP_DIR"
echo "  - Report: $REPORT_FILE"
echo ""
