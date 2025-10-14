#!/usr/bin/env bash
set -euo pipefail
OUT="docs/context/LOCAL_AGENTS.md"
TMP="$(mktemp)"
echo "# Local Agent Integration" > "$TMP"
echo "" >> "$TMP"
echo "This file is generated from local LaunchAgents. Do not edit by hand." >> "$TMP"
echo "" >> "$TMP"
echo "## Roster" >> "$TMP"
for p in "$HOME"/Library/LaunchAgents/com.02luka.*.plist; do
  [ -e "$p" ] || continue
  label=$(/usr/libexec/PlistBuddy -c 'Print :Label' "$p" 2>/dev/null || basename "$p" .plist)
  prog=$(/usr/libexec/PlistBuddy -c 'Print :Program' "$p" 2>/dev/null || true)
  if [ -z "$prog" ]; then
    prog=$(/usr/libexec/PlistBuddy -c 'Print :ProgramArguments:0' "$p" 2>/dev/null || echo "?")
  fi
  interval=$(/usr/libexec/PlistBuddy -c 'Print :StartInterval' "$p" 2>/dev/null || echo "")
  cal=$(/usr/libexec/PlistBuddy -c 'Print :StartCalendarInterval' "$p" 2>/dev/null || echo "")
  echo "- **$label** — \`$prog\` ${interval:+— every ${interval}s} ${cal:+— calendar ${cal}}" >> "$TMP"
done
echo "" >> "$TMP"
echo "## Logs" >> "$TMP"
echo "- Path: \`$HOME/Library/Logs/02luka/\`" >> "$TMP"
mv "$TMP" "$OUT"
echo "✅ updated $OUT"
