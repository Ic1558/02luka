#!/usr/bin/env zsh
# PR Workflow Scanner - Find PRs with invalid workflows/actions
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
require yq

log_info "Scanning PRs for invalid workflows/actions in $REPO..."

# Check for failing workflows first
log_info "Checking for failing workflows..."
FAILING_WORKFLOWS=$(gh run list --repo "$REPO" --limit 20 --json conclusion,status,displayTitle,createdAt,workflowName,url --jq '.[] | select(.conclusion == "failure") | "\(.workflowName)|\(.displayTitle)|\(.createdAt)|\(.url)"' 2>/dev/null || echo "")

# Fetch open PRs
PRS_JSON=$(gh pr list --repo "$REPO" --state open --limit 100 --json \
    number,title,headRefName,baseRefName,state,mergeable,mergeStateStatus,isDraft,url,labels,author 2>/dev/null || echo "[]")

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 PR Workflow Scan Results"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Show failing workflows
if [[ -n "$FAILING_WORKFLOWS" ]]; then
    FAILING_COUNT=$(echo "$FAILING_WORKFLOWS" | wc -l | tr -d ' ')
    echo "🔴 FAILING WORKFLOWS (Runtime Issues) - $FAILING_COUNT found"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "$FAILING_WORKFLOWS" | while IFS='|' read -r workflow title created url; do
        echo "  Workflow: $workflow"
        echo "  Title: $title"
        echo "  Created: $created"
        echo "  URL: $url"
        echo ""
    done
    echo ""
else
    echo "✅ No failing workflows found"
    echo ""
fi

if [[ -z "$PRS_JSON" || "$PRS_JSON" == "[]" ]]; then
    log_warn "No open PRs found"
    echo "✅ No open PRs to scan"
    if [[ -n "$FAILING_WORKFLOWS" ]]; then
        exit 1
    else
        exit 0
    fi
fi

# Check each PR for workflow issues
INVALID_COUNT=0
VALID_COUNT=0

for pr_num in $(echo "$PRS_JSON" | jq -r '.[] | .number'); do
    PR_TITLE=$(echo "$PRS_JSON" | jq -r ".[] | select(.number == $pr_num) | .title")
    PR_URL=$(echo "$PRS_JSON" | jq -r ".[] | select(.number == $pr_num) | .url")
    PR_BRANCH=$(echo "$PRS_JSON" | jq -r ".[] | select(.number == $pr_num) | .headRefName")
    
    log_info "Checking PR #$pr_num: $PR_TITLE"
    
    # Get files changed in PR
    FILES=$(gh pr view "$pr_num" --repo "$REPO" --json files --jq '.files[].path' 2>/dev/null || echo "")
    
    # Check for workflow files
    WORKFLOW_FILES=$(echo "$FILES" | grep -E '^\.github/workflows/.*\.ya?ml$' || true)
    
    if [[ -z "$WORKFLOW_FILES" ]]; then
        continue  # No workflow files in this PR
    fi
    
    ISSUES=()
    
    # Check each workflow file
    for workflow_file in $WORKFLOW_FILES; do
        # Try to fetch the file from the PR branch
        FILE_CONTENT=$(gh pr view "$pr_num" --repo "$REPO" --json headRefName --jq '.headRefName' | xargs -I {} git show "origin/{}:$workflow_file" 2>/dev/null || echo "")
        
        if [[ -z "$FILE_CONTENT" ]]; then
            # Try alternative method
            FILE_CONTENT=$(gh api "repos/$REPO/contents/$workflow_file?ref=$PR_BRANCH" --jq -r '.content' 2>/dev/null | base64 -d 2>/dev/null || echo "")
        fi
        
        if [[ -z "$FILE_CONTENT" ]]; then
            ISSUES+=("Cannot read $workflow_file")
            continue
        fi
        
        # Check YAML syntax
        if ! echo "$FILE_CONTENT" | yq eval . >/dev/null 2>&1; then
            YAML_ERROR=$(echo "$FILE_CONTENT" | yq eval . 2>&1 | head -3)
            ISSUES+=("Invalid YAML in $workflow_file: $YAML_ERROR")
        fi
        
        # Check for common workflow issues
        if echo "$FILE_CONTENT" | grep -qE 'uses:\s*[^@]*$'; then
            ISSUES+=("Missing version in action reference in $workflow_file")
        fi
        
        # Check for deprecated actions
        if echo "$FILE_CONTENT" | grep -qE 'actions/checkout@v[12]'; then
            ISSUES+=("Deprecated checkout action version in $workflow_file (use v3+)")
        fi
        
        # Check for invalid job dependencies
        if echo "$FILE_CONTENT" | grep -qE 'needs:\s*\[\]'; then
            ISSUES+=("Empty needs array in $workflow_file")
        fi
        
        # Check for missing required fields
        if ! echo "$FILE_CONTENT" | yq eval '.jobs' >/dev/null 2>&1; then
            ISSUES+=("Missing 'jobs' section in $workflow_file")
        fi
    done
    
    if [[ ${#ISSUES[@]} -gt 0 ]]; then
        INVALID_COUNT=$((INVALID_COUNT + 1))
        echo ""
        echo "🔴 PR #$pr_num: $PR_TITLE"
        echo "   Branch: $PR_BRANCH"
        echo "   URL: $PR_URL"
        echo "   Issues:"
        for issue in "${ISSUES[@]}"; do
            echo "     - $issue"
        done
    else
        VALID_COUNT=$((VALID_COUNT + 1))
    fi
done

# Also check for workflow files in main that might have issues
log_info "Checking main branch workflows..."

MAIN_WORKFLOWS=$(find .github/workflows -name "*.yml" -o -name "*.yaml" 2>/dev/null || true)

if [[ -n "$MAIN_WORKFLOWS" ]]; then
    MAIN_ISSUES=()
    for workflow_file in $MAIN_WORKFLOWS; do
        if ! yq eval . "$workflow_file" >/dev/null 2>&1; then
            YAML_ERROR=$(yq eval . "$workflow_file" 2>&1 | head -3)
            MAIN_ISSUES+=("Invalid YAML in $workflow_file: $YAML_ERROR")
        fi
    done
    
    if [[ ${#MAIN_ISSUES[@]} -gt 0 ]]; then
        echo ""
        echo "🔴 Main Branch Workflow Issues:"
        for issue in "${MAIN_ISSUES[@]}"; do
            echo "   - $issue"
        done
    fi
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📈 Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Total PRs Scanned: $(echo "$PRS_JSON" | jq 'length')"
echo "  ✅ Valid Workflows: $VALID_COUNT"
echo "  🔴 Invalid Workflows: $INVALID_COUNT"
echo ""

if [[ $INVALID_COUNT -gt 0 ]]; then
    log_warn "Found $INVALID_COUNT PR(s) with invalid workflows"
    exit 1
else
    log_success "All PR workflows are valid"
    exit 0
fi
