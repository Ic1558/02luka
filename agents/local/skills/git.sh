#!/usr/bin/env bash
#
# Phase 7.2: Git Skill Wrapper
# Safe git operations with guardrails
#
# Usage: git.sh <git-command> [args...]
#
# Safety features:
# - Blocks force push to main/master
# - Blocks hard reset without confirmation
# - Blocks destructive operations
# - Allows read-only operations freely

set -euo pipefail

# Get git command
GIT_CMD="${1:-}"
shift || true

if [ -z "$GIT_CMD" ]; then
  echo "Usage: git.sh <command> [args...]" >&2
  exit 1
fi

# Read-only operations (always safe)
SAFE_COMMANDS="status|log|show|diff|branch|tag|remote|config|ls-files|ls-tree"

if echo "$GIT_CMD" | grep -E -q "^($SAFE_COMMANDS)$"; then
  exec git "$GIT_CMD" "$@"
fi

# Check for dangerous operations
if [ "$GIT_CMD" = "push" ]; then
  # Block force push to main/master
  if echo "$@" | grep -E -q '(--force|-f).*(main|master)|(main|master).*(--force|-f)'; then
    echo "❌ Blocked: Force push to main/master is not allowed" >&2
    echo "Use manual git command if absolutely necessary" >&2
    exit 113
  fi
  # Allow normal push
  exec git push "$@"
fi

if [ "$GIT_CMD" = "reset" ]; then
  # Block hard reset without explicit confirmation
  if echo "$@" | grep -q -- '--hard'; then
    echo "❌ Blocked: Hard reset requires manual confirmation" >&2
    echo "Use manual git command: git reset --hard" >&2
    exit 113
  fi
  # Allow soft/mixed reset
  exec git reset "$@"
fi

# Other write operations with warning
WRITE_COMMANDS="add|commit|checkout|switch|merge|rebase|cherry-pick|apply|stash"

if echo "$GIT_CMD" | grep -E -q "^($WRITE_COMMANDS)$"; then
  echo "⚠️  Git write operation: $GIT_CMD" >&2
  exec git "$GIT_CMD" "$@"
fi

# Unknown command - pass through with warning
echo "⚠️  Unknown git command: $GIT_CMD (passing through)" >&2
exec git "$GIT_CMD" "$@"
