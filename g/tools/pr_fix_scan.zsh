#!/usr/bin/env zsh
# PR Fix Scanner - Identify PRs that need fixes
# Classification: Strategic Integration Patch (SIP)
# System: 02LUKA Cognitive Architecture
# Phase: 21.4 – PR Management
# Status: Active
# Maintainer: GG Core (02LUKA Automation)
# Version: v1.0.0

set -euo pipefail

REPO="${1:-Ic1558/02luka}"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m'

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

require() {
    command -v "$1" >/dev/null 2>&1 || {
        log_error "Missing required tool: $1"
        exit 1
    }
}

require gh
require jq

log_info "Scanning PRs that need fixes in $REPO..."

# Fetch open PRs
PRS_JSON=$(gh pr list --repo "$REPO" --state open --limit 100 --json \
    number,title,headRefName,baseRefName,state,mergeable,mergeStateStatus,isDraft,url,labels,author 2>/dev/null || echo "[]")

if [[ -z "$PRS_JSON" || "$PRS_JSON" == "[]" ]]; then
    log_warn "No open PRs found"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 PR Fix Scan Results"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "✅ No open PRs to scan"
    exit 0
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 PR Fix Scan Results"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check for conflicting PRs
CONFLICTING=$(echo "$PRS_JSON" | jq -r '.[] | select(.mergeable == false or .mergeStateStatus != "CLEAN") | .number')
if [[ -n "$CONFLICTING" ]]; then
    echo "🔴 CONFLICTING PRs (Need Rebase/Fix)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "$PRS_JSON" | jq -r '.[] | select(.mergeable == false or .mergeStateStatus != "CLEAN") | 
        "  PR #\(.number): \(.title)\n    Status: \(.mergeable) / \(.mergeStateStatus)\n    URL: \(.url)\n"'
    echo ""
fi

# Check for draft PRs
DRAFTS=$(echo "$PRS_JSON" | jq -r '.[] | select(.isDraft == true) | .number')
if [[ -n "$DRAFTS" ]]; then
    echo "🟡 DRAFT PRs (May Need Review)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "$PRS_JSON" | jq -r '.[] | select(.isDraft == true) | 
        "  PR #\(.number): \(.title)\n    URL: \(.url)\n"'
    echo ""
fi

# Check for PRs with failing CI
log_info "Checking CI status for PRs..."
FAILING_CI=""
for pr_num in $(echo "$PRS_JSON" | jq -r '.[] | .number'); do
    CI_STATUS=$(gh pr checks "$pr_num" --repo "$REPO" --json conclusion,status --jq '.[] | select(.conclusion == "failure" or .status == "in_progress") | .conclusion' 2>/dev/null | head -1 || echo "")
    if [[ -n "$CI_STATUS" ]]; then
        PR_TITLE=$(echo "$PRS_JSON" | jq -r ".[] | select(.number == $pr_num) | .title")
        PR_URL=$(echo "$PRS_JSON" | jq -r ".[] | select(.number == $pr_num) | .url")
        FAILING_CI="${FAILING_CI}PR #${pr_num}: ${PR_TITLE}\n  URL: ${PR_URL}\n  CI Status: ${CI_STATUS}\n\n"
    fi
done

if [[ -n "$FAILING_CI" ]]; then
    echo "🔴 PRs with Failing CI"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "$FAILING_CI"
fi

# Check for PRs modifying critical files
CRITICAL_FILES=(
    ".github/workflows/ci.yml"
    ".github/workflows/pr-score.yml"
    "package.json"
    "package-lock.json"
)

echo "🔍 PRs Modifying Critical Files"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
for pr_num in $(echo "$PRS_JSON" | jq -r '.[] | .number'); do
    FILES=$(gh pr view "$pr_num" --repo "$REPO" --json files --jq '.files[].path' 2>/dev/null || echo "")
    for critical_file in "${CRITICAL_FILES[@]}"; do
        if echo "$FILES" | grep -q "^${critical_file}$"; then
            PR_TITLE=$(echo "$PRS_JSON" | jq -r ".[] | select(.number == $pr_num) | .title")
            PR_URL=$(echo "$PRS_JSON" | jq -r ".[] | select(.number == $pr_num) | .url")
            echo "  PR #${pr_num}: ${PR_TITLE}"
            echo "    Modifies: ${critical_file}"
            echo "    URL: ${PR_URL}"
            echo ""
        fi
    done
done

# Summary
TOTAL=$(echo "$PRS_JSON" | jq 'length')
CONFLICTING_COUNT=$(echo "$PRS_JSON" | jq '[.[] | select(.mergeable == false or .mergeStateStatus != "CLEAN")] | length')
DRAFT_COUNT=$(echo "$PRS_JSON" | jq '[.[] | select(.isDraft == true)] | length')
MERGEABLE_COUNT=$(echo "$PRS_JSON" | jq '[.[] | select(.mergeable == true and .mergeStateStatus == "CLEAN" and .isDraft == false)] | length')

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📈 Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Total Open PRs: ${TOTAL}"
echo "  ✅ Mergeable: ${MERGEABLE_COUNT}"
echo "  ⚠️  Conflicting: ${CONFLICTING_COUNT}"
echo "  📝 Drafts: ${DRAFT_COUNT}"
echo ""

if [[ $CONFLICTING_COUNT -gt 0 ]]; then
    log_warn "Found ${CONFLICTING_COUNT} PR(s) that need fixes"
    exit 1
else
    log_success "All PRs are mergeable or in draft"
    exit 0
fi

