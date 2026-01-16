#!/usr/bin/env zsh
set -euo pipefail

# CI Auto-Decision — Automatic trigger and decision making
# Usage: ./tools/ci_auto_decision.zsh <PR_NUMBER>

PR_NUM="${1:-}"
if [[ -z "$PR_NUM" ]]; then
  echo "usage: $0 <PR_NUMBER>"
  exit 1
fi

echo "🤖 Auto-Decision for PR #$PR_NUM"

# 1) Check PR status
PR_INFO=$(gh pr view "$PR_NUM" --json state,mergeStateStatus,autoMergeRequest,statusCheckRollup 2>/dev/null || echo "")
if [[ -z "$PR_INFO" ]]; then
  echo "❌ PR #$PR_NUM not found"
  exit 1
fi

STATE=$(echo "$PR_INFO" | jq -r '.state')
MERGE_STATUS=$(echo "$PR_INFO" | jq -r '.mergeStateStatus')
AUTO_MERGE=$(echo "$PR_INFO" | jq -r '.autoMergeRequest != null')

# 2) Auto-decision: Set auto-merge if not set
if [[ "$AUTO_MERGE" == "false" ]] && [[ "$STATE" == "OPEN" ]]; then
  echo "🟢 Setting auto-merge for PR #$PR_NUM"
  gh pr merge "$PR_NUM" --auto --squash --delete-branch 2>/dev/null || true
fi

# 3) Auto-decision: Check for conflicts
if [[ "$MERGE_STATUS" == "DIRTY" ]] || [[ "$MERGE_STATUS" == "BLOCKED" ]]; then
  echo "⚠️  PR #$PR_NUM has conflicts or is blocked"
  
  # Try auto-fix conflicts
  if [[ "$MERGE_STATUS" == "DIRTY" ]]; then
    echo "🔧 Attempting auto-fix conflicts..."
    "$HOME/02luka/tools/dispatch_quick.zsh" auto:fix-conflict "$PR_NUM" 2>/dev/null || true
  fi
fi

# 4) Auto-decision: Check failing checks
FAILING_CHECKS=$(echo "$PR_INFO" | jq -r '.statusCheckRollup[]? | select(.conclusion == "FAILURE") | .name' | head -5)

if [[ -n "$FAILING_CHECKS" ]]; then
  echo "❌ Failing checks detected:"
  echo "$FAILING_CHECKS" | while read check; do
    echo "  - $check"
  done
  
  # Auto-decision: Rerun if failing
  echo "♻️  Auto-rerunning checks..."
  "$HOME/02luka/tools/dispatch_quick.zsh" ci:rerun "$PR_NUM" 2>/dev/null || true
fi

# 5) Auto-decision: Wait for checks (non-blocking)
echo "⏳ Waiting for CI checks (non-blocking)..."
gh pr checks "$PR_NUM" -w 2>/dev/null || true

# 6) Final status
FINAL_INFO=$(gh pr view "$PR_NUM" --json state,mergeStateStatus,autoMergeRequest --jq '{state, mergeStateStatus, autoMerge: (.autoMergeRequest != null)}' 2>/dev/null || echo "")
echo "📊 Final status: $FINAL_INFO"

echo "✅ Auto-decision complete for PR #$PR_NUM"

