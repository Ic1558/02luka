#!/usr/bin/env zsh
# Check PR status and workflow runs
# Usage: ./check-pr-status.zsh [pr-number]

set -euo pipefail

REPO="Ic1558/02luka"
PR_NUM=${1:-""}

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

if [[ -z "$PR_NUM" ]]; then
    # Show all open PRs
    log $YELLOW "📋 Open Pull Requests:"
    gh pr list --repo "$REPO" --state open
    exit 0
fi

# Get PR details
log $YELLOW "🔍 Checking PR #$PR_NUM..."
gh pr view "$PR_NUM" --repo "$REPO"

echo ""
log $YELLOW "⚙️  Workflow Status:"

# Get workflow runs for this PR
gh run list --repo "$REPO" \
    --json databaseId,name,status,conclusion,headBranch,createdAt \
    --jq ".[] | select(.headBranch == \"$(gh pr view $PR_NUM --repo $REPO --json headRefName --jq '.headRefName')\") | 
           \"\(.name): \(.status) - \(.conclusion // \"running\")\"" | head -10

echo ""
log $YELLOW "📊 PR Checks:"
gh pr checks "$PR_NUM" --repo "$REPO"

# Check if PR is ready to merge
MERGEABLE=$(gh pr view "$PR_NUM" --repo "$REPO" --json mergeable --jq '.mergeable')
if [[ "$MERGEABLE" == "MERGEABLE" ]]; then
    log $GREEN "✅ PR is ready to merge"
else
    log $RED "❌ PR has merge conflicts or is not ready"
fi
