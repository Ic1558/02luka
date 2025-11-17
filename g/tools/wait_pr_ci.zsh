#!/usr/bin/env zsh
# wait_pr_ci.zsh
# Wait for PR CI checks to complete and verify merge state
set -euo pipefail

PR_NUMBER="${1:-}"
if [[ -z "$PR_NUMBER" ]]; then
  echo "Usage: $0 <PR_NUMBER>" >&2
  echo "Example: $0 363" >&2
  exit 1
fi

MAX_WAIT="${MAX_WAIT:-600}"  # 10 minutes default
INTERVAL="${INTERVAL:-10}"   # Check every 10 seconds
ELAPSED=0

echo "⏳ Waiting for PR #$PR_NUMBER CI checks to complete..."
echo "   Max wait: ${MAX_WAIT}s, Check interval: ${INTERVAL}s"
echo ""

while [[ $ELAPSED -lt $MAX_WAIT ]]; do
  # Get PR status
  PR_STATUS=$(gh pr view "$PR_NUMBER" --json mergeable,mergeStateStatus,statusCheckRollup --jq '{
    mergeable: .mergeable,
    mergeStateStatus: .mergeStateStatus,
    checks: [.statusCheckRollup[] | select(.conclusion == null) | {name: .name, status: .status}]
  }' 2>/dev/null || echo '{}')
  
  MERGEABLE=$(echo "$PR_STATUS" | jq -r '.mergeable // "UNKNOWN"')
  MERGE_STATE=$(echo "$PR_STATUS" | jq -r '.mergeStateStatus // "UNKNOWN"')
  PENDING_COUNT=$(echo "$PR_STATUS" | jq '.checks | length')
  
  if [[ "$PENDING_COUNT" == "0" ]]; then
    echo ""
    echo "✅ All CI checks completed!"
    echo ""
    echo "Final Status:"
    echo "  Mergeable: $MERGEABLE"
    echo "  Merge State: $MERGE_STATE"
    echo ""
    
    if [[ "$MERGEABLE" == "MERGEABLE" && "$MERGE_STATE" == "CLEAN" ]]; then
      echo "🎉 PR #$PR_NUMBER is ready for merge!"
      exit 0
    elif [[ "$MERGEABLE" == "MERGEABLE" ]]; then
      echo "⚠️  PR is mergeable but merge state is: $MERGE_STATE"
      echo "   (May need to wait a bit longer for merge state to update)"
      exit 0
    else
      echo "❌ PR is not mergeable: $MERGEABLE"
      echo "   Merge State: $MERGE_STATE"
      exit 1
    fi
  fi
  
  if [[ $((ELAPSED % 30)) -eq 0 ]]; then
    echo "[${ELAPSED}s] $PENDING_COUNT checks still pending... (mergeable=$MERGEABLE, state=$MERGE_STATE)"
  fi
  
  sleep "$INTERVAL"
  ELAPSED=$((ELAPSED + INTERVAL))
done

echo ""
echo "⏱️  Timeout reached (${MAX_WAIT}s)"
echo "   Checking final status..."
gh pr view "$PR_NUMBER" --json mergeable,mergeStateStatus --jq '{
  mergeable: .mergeable,
  mergeStateStatus: .mergeStateStatus
}'
exit 1
