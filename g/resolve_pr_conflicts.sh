#!/bin/bash
# Automated PR Conflict Resolution Script
# Resolves all 4 conflicting authentication feature branches

set -euo pipefail

echo "PR Conflict Resolution Tool"
echo "============================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

BRANCHES=(
  "codex/add-user-authentication-feature"
  "codex/add-user-authentication-feature-hhs830"
  "codex/add-user-authentication-feature-not1zo"
  "codex/add-user-authentication-feature-yiytty"
)

RESOLVED=0
FAILED=0

resolve_branch() {
  local branch="$1"

  echo -e "${YELLOW}Processing: ${branch}${NC}"

  # Check if branch exists
  if ! git show-ref --verify --quiet "refs/remotes/origin/${branch}"; then
    echo -e "${RED}  ✗ Branch not found in remote${NC}"
    return 1
  fi

  # Checkout the branch
  echo "  Checking out branch..."
  if ! git checkout "${branch}" 2>/dev/null; then
    echo "  Creating local tracking branch..."
    git checkout -b "${branch}" "origin/${branch}"
  fi

  # Attempt merge
  echo "  Merging main..."
  if git merge origin/main --no-commit --no-ff 2>&1 | grep -q "Automatic merge failed"; then
    echo "  Conflicts detected, resolving..."

    # Resolve boss-api/server.cjs (accept deletion)
    if [ -f boss-api/server.cjs ]; then
      echo "    - Removing boss-api/server.cjs (architecture changed)"
      git rm boss-api/server.cjs
    fi

    # Resolve scripts/smoke.sh (accept main's version)
    if git status | grep -q "scripts/smoke.sh"; then
      echo "    - Accepting main's version of scripts/smoke.sh"
      git checkout --theirs scripts/smoke.sh
      git add scripts/smoke.sh
    fi

    # Commit the resolution
    echo "  Committing merge resolution..."
    git commit -m "Resolve merge conflicts with main

- Accept deletion of boss-api/server.cjs (architecture changed)
- Accept main's version of scripts/smoke.sh (tests current system)
- Branch changes are obsolete due to architecture evolution

Automated resolution by resolve_pr_conflicts.sh"

    echo -e "${GREEN}  ✓ Conflicts resolved and committed${NC}"

    # Try to push (may fail due to permissions)
    echo "  Attempting to push..."
    if git push origin "${branch}" 2>&1; then
      echo -e "${GREEN}  ✓ Successfully pushed to remote${NC}"
      RESOLVED=$((RESOLVED + 1))
      return 0
    else
      echo -e "${YELLOW}  ⚠ Could not push (permission denied)${NC}"
      echo -e "${YELLOW}  ℹ Local branch resolved - manual push required${NC}"
      RESOLVED=$((RESOLVED + 1))
      return 0
    fi
  else
    # No conflicts
    echo -e "${GREEN}  ✓ No conflicts - branch already up to date${NC}"
    git merge --abort 2>/dev/null || true
    RESOLVED=$((RESOLVED + 1))
    return 0
  fi
}

# Main execution
echo "Starting resolution of ${#BRANCHES[@]} conflicting branches..."
echo ""

for branch in "${BRANCHES[@]}"; do
  if resolve_branch "$branch"; then
    echo ""
  else
    FAILED=$((FAILED + 1))
    echo -e "${RED}Failed to resolve ${branch}${NC}"
    echo ""
  fi
done

# Summary
echo "=========================================="
echo "Resolution Summary:"
echo "  Resolved: ${RESOLVED}/${#BRANCHES[@]}"
echo "  Failed: ${FAILED}/${#BRANCHES[@]}"
echo ""

if [ $FAILED -eq 0 ]; then
  echo -e "${GREEN}✓ All conflicts resolved successfully!${NC}"
  exit 0
else
  echo -e "${YELLOW}⚠ Some branches could not be resolved${NC}"
  exit 1
fi
