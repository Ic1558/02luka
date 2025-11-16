#!/usr/bin/env zsh
# CI Merge Strategy Scanner
# Scans PRs that modify ci.yml and provides merge strategy recommendations
# Classification: Strategic Integration Patch (SIP)
# System: 02LUKA Cognitive Architecture
# Phase: 21.4 – CI Workflow Refactoring
# Status: Active
# Maintainer: GG Core (02LUKA Automation)
# Version: v1.0.0

set -euo pipefail

REPO="${1:-Ic1558/02luka}"
OUTPUT_FILE="${2:-/tmp/ci_yml_prs.txt}"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[scan]${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}[scan]${NC} ✓ $*" >&2
}

log_warn() {
    echo -e "${YELLOW}[scan]${NC} ⚠ $*" >&2
}

log_error() {
    echo -e "${RED}[scan]${NC} ✗ $*" >&2
}

log_info "Scanning PRs that modify .github/workflows/ci.yml in $REPO ..."

# Check if gh CLI is available
if ! command -v gh >/dev/null 2>&1; then
    log_error "GitHub CLI (gh) is not installed"
    log_info "Install with: brew install gh"
    exit 1
fi

# Check if jq is available
if ! command -v jq >/dev/null 2>&1; then
    log_error "jq is not installed"
    log_info "Install with: brew install jq"
    exit 1
fi

# Fetch all open PRs
log_info "Fetching open PRs..."
gh pr list --repo "$REPO" --state open --limit 100 --json number,title,headRefName,mergeable,createdAt > /tmp/pr_list.json 2>/dev/null || {
    log_error "Failed to fetch PRs. Check GitHub CLI authentication: gh auth login"
    exit 1
}

TOTAL_PRS=$(jq 'length' /tmp/pr_list.json)
log_info "Found $TOTAL_PRS open PR(s)"

# Scan for PRs that modify ci.yml
CI_YML_PRS=()
INDEPENDENT_PRS=()

log_info "Scanning for PRs that modify .github/workflows/ci.yml..."

jq -r '.[].number' /tmp/pr_list.json | while read -r PR; do
    log_info "Checking PR #$PR..."
    
    # Get PR files
    PR_FILES=$(gh pr view "$PR" --repo "$REPO" --json files --jq '.files[].path' 2>/dev/null || echo "")
    
    if echo "$PR_FILES" | grep -q "^\.github/workflows/ci\.yml$"; then
        # This PR modifies ci.yml
        PR_INFO=$(gh pr view "$PR" --repo "$REPO" --json number,title,headRefName,mergeable,createdAt 2>/dev/null || echo "{}")
        
        if echo "$PR_INFO" | jq -e '.mergeable' >/dev/null 2>&1; then
            MERGEABLE=$(echo "$PR_INFO" | jq -r '.mergeable // "UNKNOWN"')
            TITLE=$(echo "$PR_INFO" | jq -r '.title')
            BRANCH=$(echo "$PR_INFO" | jq -r '.headRefName')
            CREATED=$(echo "$PR_INFO" | jq -r '.createdAt')
            
            echo "PR #$PR ($MERGEABLE): $TITLE"
            echo "  Branch: $BRANCH"
            echo "  Created: $CREATED"
            echo ""
            
            CI_YML_PRS+=("$PR")
        fi
    else
        # Independent PR - doesn't modify ci.yml
        PR_INFO=$(gh pr view "$PR" --repo "$REPO" --json number,title,headRefName 2>/dev/null || echo "{}")
        TITLE=$(echo "$PR_INFO" | jq -r '.title // "N/A"')
        BRANCH=$(echo "$PR_INFO" | jq -r '.headRefName // "N/A"')
        
        INDEPENDENT_PRS+=("PR #$PR: $TITLE ($BRANCH)")
    fi
done | tee "$OUTPUT_FILE"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Scan Results"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Count PRs
CI_YML_COUNT=$(grep -c "^PR #" "$OUTPUT_FILE" 2>/dev/null || echo "0")
INDEPENDENT_COUNT=$((TOTAL_PRS - CI_YML_COUNT))

if [[ $CI_YML_COUNT -eq 0 ]]; then
    log_success "No PRs modify ci.yml - all PRs are independent!"
    echo ""
    echo "✅ All PRs can be merged independently"
    echo "✅ No merge coordination needed"
else
    log_warn "Found $CI_YML_COUNT PR(s) that modify ci.yml"
    echo ""
    echo "📋 PRs modifying ci.yml:"
    cat "$OUTPUT_FILE"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🎯 Recommended Merge Strategy"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "✅ Step 1: Merge independent PRs first (no ci.yml conflicts)"
    echo "   - Agent Heartbeat PR"
    echo "   - Any other PRs that don't modify ci.yml"
    echo ""
    echo "✅ Step 2: Merge PR #201 (CI Reliability Pack) first"
    echo "   - This has broader changes to ci.yml structure"
    echo "   - After merge, main will have the refactored ci.yml"
    echo ""
    echo "✅ Step 3: Rebase remaining PRs on updated main"
    echo "   - PR #197 (Router Core) should rebase after #201 merges"
    echo "   - Any other PRs modifying ci.yml"
    echo ""
    echo "✅ Step 4: Merge rebased PRs"
    echo ""
fi

echo ""
echo "📁 Results saved to: $OUTPUT_FILE"
echo ""
echo "💡 Note: With the new reusable workflow architecture,"
echo "   most PRs can modify wrapper workflows independently"
echo "   without touching ci.yml!"
