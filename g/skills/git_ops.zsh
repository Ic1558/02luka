#!/usr/bin/env zsh
set -euo pipefail

# Skill: git_ops - Git operations (status, add, commit, branch) - local only
# Input: {"skill":"git_ops","params":{"action":"status|add|commit|branch","path":"...","message":"...","branch":"..."}}
# Output: {"ok":true,"output":"...","duration_ms":123}

INPUT=$(cat)
ACTION=$(echo "$INPUT" | jq -r '.params.action')
REPO_PATH=$(echo "$INPUT" | jq -r '.params.path // "."')
MESSAGE=$(echo "$INPUT" | jq -r '.params.message // empty')
BRANCH=$(echo "$INPUT" | jq -r '.params.branch // empty')

START=$(date +%s%3N)

# Change to repo directory
cd "$REPO_PATH" 2>/dev/null || {
  print -r -- "{\"ok\":false,\"error\":\"invalid path: $REPO_PATH\"}"
  exit 0
}

OUTPUT=""
EXIT_CODE=0

case "$ACTION" in
  status)
    OUTPUT=$(git status 2>&1) || EXIT_CODE=$?
    ;;
  add)
    FILES=$(echo "$INPUT" | jq -r '.params.files // "."')
    OUTPUT=$(git add $FILES 2>&1) || EXIT_CODE=$?
    ;;
  commit)
    if [[ -z "$MESSAGE" ]]; then
      print -r -- '{"ok":false,"error":"message required for commit"}'
      exit 0
    fi
    OUTPUT=$(git commit -m "$MESSAGE" 2>&1) || EXIT_CODE=$?
    ;;
  branch)
    if [[ -n "$BRANCH" ]]; then
      OUTPUT=$(git checkout -b "$BRANCH" 2>&1) || EXIT_CODE=$?
    else
      OUTPUT=$(git branch 2>&1) || EXIT_CODE=$?
    fi
    ;;
  *)
    print -r -- "{\"ok\":false,\"error\":\"unknown action: $ACTION\"}"
    exit 0
    ;;
esac

END=$(date +%s%3N)
DURATION=$((END - START))

print -r -- "{\"ok\":$([ $EXIT_CODE -eq 0 ] && echo true || echo false),\"action\":\"$ACTION\",\"output\":$(echo "$OUTPUT" | jq -Rs .),\"duration_ms\":$DURATION}"
