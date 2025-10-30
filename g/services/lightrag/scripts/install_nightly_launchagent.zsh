#!/usr/bin/env zsh
set -euo pipefail

SCHEDULE="${1:-02:30}"
BASE="$HOME/02luka/g/services/lightrag"
PLIST="$HOME/Library/LaunchAgents/com.02luka.lightrag.nightly.ingest.plist"

if [[ ! -x "$BASE/ingest_all.zsh" ]]; then
  echo "ingest_all.zsh not found at $BASE" >&2
  exit 1
fi

if [[ ! $SCHEDULE =~ ^[0-9]{1,2}:[0-9]{2}$ ]]; then
  echo "Invalid time format. Use HH:MM (24h)." >&2
  exit 1
fi

HOUR=${SCHEDULE%:*}
MINUTE=${SCHEDULE#*:}

cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.02luka.lightrag.nightly.ingest</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/zsh</string>
    <string>-lc</string>
    <string>~/02luka/g/services/lightrag/ingest_all.zsh</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key><integer>${HOUR}</integer>
    <key>Minute</key><integer>${MINUTE}</integer>
  </dict>
  <key>StandardOutPath</key><string>/tmp/lightrag_ingest_all.out</string>
  <key>StandardErrorPath</key><string>/tmp/lightrag_ingest_all.err</string>
</dict></plist>
PLIST

launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"

echo "Nightly re-ingest scheduled at ${HOUR}:${MINUTE}" 
