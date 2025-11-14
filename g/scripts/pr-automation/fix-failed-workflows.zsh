#!/usr/bin/env zsh
# Auto-retry failed workflows
# Usage: ./fix-failed-workflows.zsh

set -euo pipefail

REPO="Ic1558/02luka"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

log $YELLOW "🔍 Checking for failed workflow runs..."

# Get recent failed runs
FAILED_RUNS=$(gh run list --repo "$REPO" \
    --limit 20 \
    --json databaseId,name,status,conclusion,headBranch,createdAt \
    --jq '.[] | select(.conclusion == "failure") | .databaseId')

if [[ -z "$FAILED_RUNS" ]]; then
    log $GREEN "✅ No recent failed workflows found"
    exit 0
fi

COUNT=0
for RUN_ID in $FAILED_RUNS; do
    RUN_INFO=$(gh run view "$RUN_ID" --repo "$REPO" --json name,headBranch,conclusion)
    NAME=$(echo "$RUN_INFO" | jq -r '.name')
    BRANCH=$(echo "$RUN_INFO" | jq -r '.headBranch')
    
    log $YELLOW "🔄 Found failed run: $NAME (branch: $BRANCH)"
    
    # Ask if user wants to retry
    if [[ "${AUTO_RETRY:-no}" == "yes" ]]; then
        RETRY="y"
    else
        echo -n "Retry this workflow? [y/N] "
        read RETRY
    fi
    
    if [[ "$RETRY" =~ ^[Yy]$ ]]; then
        log $YELLOW "♻️  Retrying run $RUN_ID..."
        gh run rerun "$RUN_ID" --repo "$REPO"
        COUNT=$((COUNT + 1))
        log $GREEN "✅ Retry triggered"
    fi
done

if [[ $COUNT -gt 0 ]]; then
    log $GREEN "✅ Retried $COUNT workflow(s)"
else
    log $YELLOW "⚠️  No workflows retried"
fi
