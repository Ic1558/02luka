#!/usr/bin/env zsh
set -euo pipefail

# Skill: launchctl_ctl - Control LaunchAgents
# Input: {"skill":"launchctl_ctl","params":{"action":"kickstart|list|load|unload","agent":"com.02luka.xxx"}}
# Output: {"ok":true,"output":"...","duration_ms":123}

INPUT=$(cat)
ACTION=$(echo "$INPUT" | jq -r '.params.action')
AGENT=$(echo "$INPUT" | jq -r '.params.agent // empty')

# macOS-compatible millisecond timestamp
START=$(python3 -c 'import time; print(int(time.time() * 1000))')

# Validate agent name (must be com.02luka.*)
if [[ -n "$AGENT" && ! "$AGENT" =~ ^com\.02luka\. ]]; then
  print -r -- '{"ok":false,"error":"agent must start with com.02luka."}'
  exit 0
fi

OUTPUT=""
EXIT_CODE=0

case "$ACTION" in
  list)
    OUTPUT=$(launchctl list | grep "02luka" 2>&1) || EXIT_CODE=$?
    ;;
  kickstart)
    if [[ -z "$AGENT" ]]; then
      print -r -- '{"ok":false,"error":"agent name required for kickstart"}'
      exit 0
    fi
    OUTPUT=$(launchctl kickstart -k gui/$(id -u)/"$AGENT" 2>&1) || EXIT_CODE=$?
    ;;
  load)
    if [[ -z "$AGENT" ]]; then
      print -r -- '{"ok":false,"error":"agent name required for load"}'
      exit 0
    fi
    PLIST="$HOME/Library/LaunchAgents/${AGENT}.plist"
    OUTPUT=$(launchctl load "$PLIST" 2>&1) || EXIT_CODE=$?
    ;;
  unload)
    if [[ -z "$AGENT" ]]; then
      print -r -- '{"ok":false,"error":"agent name required for unload"}'
      exit 0
    fi
    PLIST="$HOME/Library/LaunchAgents/${AGENT}.plist"
    OUTPUT=$(launchctl unload "$PLIST" 2>&1) || EXIT_CODE=$?
    ;;
  *)
    print -r -- "{\"ok\":false,\"error\":\"unknown action: $ACTION\"}"
    exit 0
    ;;
esac

# macOS-compatible millisecond timestamp
END=$(python3 -c 'import time; print(int(time.time() * 1000))')
DURATION=$((END - START))

print -r -- "{\"ok\":$([ $EXIT_CODE -eq 0 ] && echo true || echo false),\"action\":\"$ACTION\",\"output\":$(echo "$OUTPUT" | jq -Rs .),\"duration_ms\":$DURATION}"
