#!/usr/bin/env zsh
set -euo pipefail

# Skill: file_query - Find and summarize files using ripgrep/fd/du
# Input: {"skill":"file_query","params":{"type":"find|grep|du","pattern":"...","path":"..."}}
# Output: {"ok":true,"results":"...","duration_ms":123}

INPUT=$(cat)
TYPE=$(echo "$INPUT" | jq -r '.params.type')
PATTERN=$(echo "$INPUT" | jq -r '.params.pattern // empty')
PATH=$(echo "$INPUT" | jq -r '.params.path // "."')

START=$(date +%s%3N)

OUTPUT=""
EXIT_CODE=0

case "$TYPE" in
  find)
    # Use fd to find files
    if command -v fd >/dev/null 2>&1; then
      OUTPUT=$(fd -t f "$PATTERN" "$PATH" 2>&1) || EXIT_CODE=$?
    else
      OUTPUT=$(find "$PATH" -type f -name "$PATTERN" 2>&1) || EXIT_CODE=$?
    fi
    ;;
  grep)
    # Use ripgrep to search content
    if command -v rg >/dev/null 2>&1; then
      OUTPUT=$(rg -l "$PATTERN" "$PATH" 2>&1) || EXIT_CODE=$?
    else
      OUTPUT=$(grep -r "$PATTERN" "$PATH" 2>&1) || EXIT_CODE=$?
    fi
    ;;
  du)
    # Disk usage
    OUTPUT=$(du -sh "$PATH" 2>&1) || EXIT_CODE=$?
    ;;
  *)
    print -r -- "{\"ok\":false,\"error\":\"unknown type: $TYPE (use find, grep, or du)\"}"
    exit 0
    ;;
esac

END=$(date +%s%3N)
DURATION=$((END - START))

print -r -- "{\"ok\":$([ $EXIT_CODE -eq 0 ] && echo true || echo false),\"type\":\"$TYPE\",\"results\":$(echo "$OUTPUT" | jq -Rs .),\"duration_ms\":$DURATION}"
