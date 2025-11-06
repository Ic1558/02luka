#!/bin/bash
# PR Management Script
# This script handles merging, re-running checks, rebasing, and monitoring PRs
# Requires: GitHub CLI (gh) to be installed and authenticated
#
# Usage:
#   ./scripts/manage_prs.sh              # Normal execution
#   DRY_RUN=1 ./scripts/manage_prs.sh    # Preview actions without executing
#   SKIP_SANITY=1 ./scripts/manage_prs.sh  # Skip sanity checks at end
#
# Environment variables:
#   DRY_RUN      - Set to 1 to preview actions without executing
#   SKIP_SANITY  - Set to 1 to skip post-execution sanity checks
#   RETRY_DELAY  - Base delay in seconds between retries (default: 2)

set -euo pipefail

# Configuration
DRY_RUN="${DRY_RUN:-0}"
SKIP_SANITY="${SKIP_SANITY:-0}"
RETRY_DELAY="${RETRY_DELAY:-2}"
MAX_RETRIES=3

# Colors for output
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
else
    RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

# Helper: execute or dry-run a command
run_cmd() {
    local cmd="$*"
    if [[ "$DRY_RUN" == "1" ]]; then
        echo -e "${BLUE}[DRY-RUN]${NC} $cmd"
        return 0
    else
        echo -e "${GREEN}[EXEC]${NC} $cmd"
        eval "$cmd"
    fi
}

# Helper: retry with exponential backoff
retry_cmd() {
    local cmd="$*"
    local attempt=1
    local delay="$RETRY_DELAY"

    while [[ $attempt -le $MAX_RETRIES ]]; do
        if run_cmd "$cmd"; then
            return 0
        else
            if [[ $attempt -lt $MAX_RETRIES ]]; then
                echo -e "${YELLOW}  ↳ Retry $attempt/$MAX_RETRIES failed, waiting ${delay}s...${NC}"
                sleep "$delay"
                delay=$((delay * 2))
                attempt=$((attempt + 1))
            else
                echo -e "${RED}  ✗ Failed after $MAX_RETRIES attempts${NC}"
                return 1
            fi
        fi
    done
}

# Helper: merge PR with retry and rate limiting
pr_merge() {
    local pr="$1"
    echo -e "\n${BLUE}→${NC} Merging PR #$pr..."
    retry_cmd "gh pr merge $pr --squash --delete-branch" || true
    sleep 1  # Rate limiting
}

# Helper: re-run checks with retry and rate limiting
pr_rerun_checks() {
    local pr="$1"
    echo -e "\n${BLUE}→${NC} Re-running checks for PR #$pr..."
    retry_cmd "gh pr checks $pr --re-run" || true
    sleep 1  # Rate limiting
}

echo "╔════════════════════════════════════════════════════════════╗"
echo "║          PR Management Script                              ║"
echo "╚════════════════════════════════════════════════════════════╝"
if [[ "$DRY_RUN" == "1" ]]; then
    echo -e "${YELLOW}⚠ DRY-RUN MODE: No changes will be made${NC}\n"
fi

echo -e "\n${GREEN}═══${NC} Phase 1: Merging PRs with squash ${GREEN}═══${NC}"
for pr in 182 181 114 113; do
    pr_merge "$pr"
done

echo -e "\n${GREEN}═══${NC} Phase 2: Re-running checks for PRs ${GREEN}═══${NC}"
for pr in 123 124 125 126 127 128 129; do
    pr_rerun_checks "$pr"
done

echo -e "\n${GREEN}═══${NC} Phase 3: Rebasing PR 169 on main ${GREEN}═══${NC}"
if [[ "$DRY_RUN" == "1" ]]; then
    echo -e "${BLUE}[DRY-RUN]${NC} gh pr checkout 169"
    echo -e "${BLUE}[DRY-RUN]${NC} git rebase origin/main"
    echo -e "${BLUE}[DRY-RUN]${NC} git push --force-with-lease"
else
    echo -e "${GREEN}[EXEC]${NC} Checking out PR 169..."
    gh pr checkout 169
    echo -e "${GREEN}[EXEC]${NC} Rebasing on origin/main..."
    git rebase origin/main
    echo -e "${GREEN}[EXEC]${NC} Force-pushing with lease..."
    git push --force-with-lease
fi

echo -e "\n${GREEN}═══${NC} Phase 4: Watching checks for PR 164 ${GREEN}═══${NC}"
if [[ "$DRY_RUN" == "1" ]]; then
    echo -e "${BLUE}[DRY-RUN]${NC} gh pr checks 164 -w"
else
    gh pr checks 164 -w
fi

# Sanity checks (optional)
if [[ "$SKIP_SANITY" != "1" ]] && [[ "$DRY_RUN" != "1" ]]; then
    echo -e "\n${GREEN}═══${NC} Sanity Checks ${GREEN}═══${NC}"

    echo -e "\n${BLUE}Merged PR states:${NC}"
    for pr in 182 181 114 113; do
        state=$(gh pr view "$pr" --json state -q .state 2>/dev/null || echo "ERROR")
        if [[ "$state" == "MERGED" ]]; then
            echo -e "  PR #$pr: ${GREEN}✓ $state${NC}"
        else
            echo -e "  PR #$pr: ${YELLOW}⚠ $state${NC}"
        fi
    done

    echo -e "\n${BLUE}Check statuses for re-run PRs (sample):${NC}"
    for pr in 123 129; do
        echo -e "  PR #$pr:"
        gh pr checks "$pr" 2>/dev/null | head -n 3 || echo "    (unable to fetch)"
    done

    echo -e "\n${BLUE}PR 169 rebase status:${NC}"
    gh pr view 169 --json headRefName,mergeable -q '  Branch: \(.headRefName)\n  Mergeable: \(.mergeable)' 2>/dev/null || echo "  (unable to fetch)"
fi

echo -e "\n${GREEN}✓ All operations completed${NC}"
echo "Run timestamp: $(date -Iseconds)"
