#!/usr/bin/env zsh
# check_wo_pattern.zsh - Check if issues should be fixed directly or via WO
# Usage: check_wo_pattern.zsh <issue_count> [critical]
# Returns: 0 = fix directly, 1 = create WO, 2 = error

set -euo pipefail

# Pattern: 0-1 critical → Fix directly, 2+ → Create WO
# See: .cursorrules "Work Order (WO) Creation Decision Pattern"

ISSUE_COUNT="${1:-0}"
IS_CRITICAL="${2:-false}"

# Validate input
if ! [[ "$ISSUE_COUNT" =~ ^[0-9]+$ ]]; then
  echo "ERROR: Issue count must be a number" >&2
  exit 2
fi

# Decision logic
if (( ISSUE_COUNT <= 1 )); then
  if [[ "$IS_CRITICAL" == "true" ]] || (( ISSUE_COUNT == 1 )); then
    echo "✅ Fix DIRECTLY (${ISSUE_COUNT} critical issue)"
    exit 0
  else
    echo "✅ Fix DIRECTLY (${ISSUE_COUNT} issues)"
    exit 0
  fi
elif (( ISSUE_COUNT >= 2 )); then
  echo "⚠️  CREATE WO (${ISSUE_COUNT} issues detected)"
  echo "📋 Pattern: 2+ issues → Create WO"
  exit 1
fi

# Should not reach here
exit 2
