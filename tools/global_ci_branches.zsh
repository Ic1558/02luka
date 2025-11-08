#!/usr/bin/env bash
#
# Global CI Branches Rebase Tool
# Discovers and rebases all open PRs that modify CI workflows
#
# Features:
# - Safe by default (dry-run mode)
# - Fork detection and protection
# - Branch ownership validation
# - Rate limit awareness
# - Conflict handling with backups
# - Resume-ability via state file
# - Required checks filtering
#
# Usage:
#   global_ci_branches.zsh [--report | --rebase] [OPTIONS]
#
# Options:
#   --report              List candidate PRs (default, read-only)
#   --rebase              Perform rebase operations (requires confirmation)
#   --force               Skip confirmation prompt
#   --base BRANCH         Rebase onto BRANCH (default: origin/main)
#   --limit N             Limit PR discovery to N PRs (default: 100)
#   --only-failing        Only rebase PRs with failing checks
#   --allow-forks         Include PRs from forks (unsafe, off by default)
#   --include PATTERN     Include PRs matching PATTERN (branch or title)
#   --exclude PATTERN     Exclude PRs matching PATTERN
#   --state-file PATH     Path to state file (default: /tmp/global-ci-rebase.json)
#   --repo OWNER/NAME     Target repository (default: from git remote)
#
# Examples:
#   # List all candidate PRs
#   ./global_ci_branches.zsh
#
#   # Rebase all CI PRs onto main
#   ./global_ci_branches.zsh --rebase
#
#   # Rebase only failing PRs, no confirmation
#   ./global_ci_branches.zsh --rebase --only-failing --force
#
#   # Rebase onto develop branch
#   ./global_ci_branches.zsh --rebase --base origin/develop
#

set -euo pipefail

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Configuration & Defaults
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

BASE="origin/main"
MODE="report"
FORCE=0
LIMIT=100
ONLY_FAILING=0
ALLOW_FORKS=0
STATE_FILE="/tmp/global-ci-rebase.json"
REPO=""
INCLUDE_PATTERNS=()
EXCLUDE_PATTERNS=()

# CI workflow patterns to match (relative to repo root)
CI_PATTERNS=(
  ".github/workflows/ci.yml"
  ".github/workflows/_reusable/*.yml"
)

# Protected branches that should never be rebased
PROTECTED_BRANCHES=(
  "main"
  "master"
  "develop"
  "production"
)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Helper Functions
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

log() {
  local color=$1; shift
  echo -e "${color}$@${NC}" >&2
}

error() {
  log "$RED" "❌ ERROR: $@"
  exit 1
}

warn() {
  log "$YELLOW" "⚠️  WARNING: $@"
}

info() {
  log "$CYAN" "ℹ️  $@"
}

success() {
  log "$GREEN" "✅ $@"
}

# Check if a command exists
need() {
  command -v "$1" >/dev/null 2>&1 || error "Missing required tool: $1"
}

# Check if branch is protected
is_protected_branch() {
  local branch=$1
  for protected in "${PROTECTED_BRANCHES[@]}"; do
    if [[ "$branch" == "$protected" ]]; then
      return 0
    fi
  done
  return 1
}

# Match pattern against string
matches_pattern() {
  local string=$1
  local pattern=$2
  [[ "$string" == *${pattern}* ]]
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Argument Parsing
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

show_help() {
  sed -n '2,/^$/p' "$0" | sed 's/^# //' | sed 's/^#//'
  exit 0
}

while (( $# )); do
  case "$1" in
    --help|-h)
      show_help
      ;;
    --report)
      MODE="report"
      ;;
    --rebase)
      MODE="rebase"
      ;;
    --force)
      FORCE=1
      ;;
    --base)
      BASE="${2}"
      shift
      ;;
    --limit)
      LIMIT="${2}"
      shift
      ;;
    --only-failing)
      ONLY_FAILING=1
      ;;
    --allow-forks)
      ALLOW_FORKS=1
      warn "Fork rebasing enabled - ensure you have proper permissions"
      ;;
    --include)
      INCLUDE_PATTERNS+=("${2}")
      shift
      ;;
    --exclude)
      EXCLUDE_PATTERNS+=("${2}")
      shift
      ;;
    --state-file)
      STATE_FILE="${2}"
      shift
      ;;
    --repo)
      REPO="${2}"
      shift
      ;;
    *)
      error "Unknown argument: $1 (use --help for usage)"
      ;;
  esac
  shift
done

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Preflight Checks
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

info "Starting Global CI Rebase Tool (mode: $MODE)"

# Check required tools
need gh
need jq
need git

# Verify git repository
if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
  error "Not in a git repository"
fi

# Check GitHub CLI authentication
if ! gh auth status >/dev/null 2>&1; then
  error "GitHub CLI not authenticated (run: gh auth login)"
fi

# Auto-detect repository if not specified
if [[ -z "$REPO" ]]; then
  REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || echo "")
  if [[ -z "$REPO" ]]; then
    error "Could not auto-detect repository. Use --repo OWNER/NAME"
  fi
fi

info "Target repository: $REPO"
info "Rebase base: $BASE"

# Check rate limit
RATE_LIMIT_JSON=$(gh api rate_limit 2>/dev/null || echo '{}')
REMAINING=$(echo "$RATE_LIMIT_JSON" | jq -r '.resources.core.remaining // 0')
LIMIT_TOTAL=$(echo "$RATE_LIMIT_JSON" | jq -r '.resources.core.limit // 5000')

if [[ "$REMAINING" -lt 50 ]]; then
  warn "GitHub API rate limit low: $REMAINING/$LIMIT_TOTAL remaining"
  if [[ "$REMAINING" -lt 10 ]]; then
    error "Rate limit too low to proceed safely. Wait for reset."
  fi
fi

info "API rate limit: $REMAINING/$LIMIT_TOTAL"

# Get base repository info for fork detection
BASE_REPO_JSON=$(gh repo view "$REPO" --json owner,name)
BASE_OWNER=$(echo "$BASE_REPO_JSON" | jq -r '.owner.login')
BASE_NAME=$(echo "$BASE_REPO_JSON" | jq -r '.name')

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PR Discovery Phase
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

info "Discovering open PRs (limit: $LIMIT)..."

# Fetch all open PRs
PRS_JSON=$(gh pr list \
  --repo "$REPO" \
  --state open \
  --limit "$LIMIT" \
  --json number,title,headRefName,headRepository,headRepositoryOwner 2>/dev/null)

if [[ -z "$PRS_JSON" || "$PRS_JSON" == "[]" ]]; then
  info "No open PRs found"
  exit 0
fi

PR_NUMBERS=($(echo "$PRS_JSON" | jq -r '.[].number'))
info "Found ${#PR_NUMBERS[@]} open PRs, analyzing..."

# Analyze each PR
declare -A CANDIDATES  # Associative array: PR_NUM => BRANCH_NAME
declare -A PR_TITLES   # PR_NUM => TITLE
declare -A SKIP_REASONS # PR_NUM => REASON

for PR_NUM in "${PR_NUMBERS[@]}"; do
  # Get detailed PR info including files
  PR_JSON=$(gh pr view "$PR_NUM" \
    --repo "$REPO" \
    --json number,title,headRefName,files,headRepository,headRepositoryOwner,mergeable \
    2>/dev/null || echo '{}')

  if [[ "$PR_JSON" == "{}" ]]; then
    SKIP_REASONS[$PR_NUM]="Failed to fetch PR data"
    continue
  fi

  BRANCH=$(echo "$PR_JSON" | jq -r '.headRefName // empty')
  TITLE=$(echo "$PR_JSON" | jq -r '.title // empty')
  HEAD_OWNER=$(echo "$PR_JSON" | jq -r '.headRepositoryOwner.login // empty')
  HEAD_REPO=$(echo "$PR_JSON" | jq -r '.headRepository.name // empty')

  PR_TITLES[$PR_NUM]="$TITLE"

  # Check 1: Protected branch
  if is_protected_branch "$BRANCH"; then
    SKIP_REASONS[$PR_NUM]="Protected branch: $BRANCH"
    continue
  fi

  # Check 2: Fork detection
  if [[ "$HEAD_OWNER" != "$BASE_OWNER" || "$HEAD_REPO" != "$BASE_NAME" ]]; then
    if (( ! ALLOW_FORKS )); then
      SKIP_REASONS[$PR_NUM]="External fork: $HEAD_OWNER/$HEAD_REPO (use --allow-forks)"
      continue
    fi
  fi

  # Check 3: File changes - must touch CI workflows
  TOUCHES_CI=0
  while IFS= read -r filepath; do
    # Check against CI patterns
    if [[ "$filepath" == ".github/workflows/ci.yml" ]]; then
      TOUCHES_CI=1
      break
    fi
    if [[ "$filepath" =~ ^\.github/workflows/_reusable/.*\.yml$ ]]; then
      TOUCHES_CI=1
      break
    fi
  done < <(echo "$PR_JSON" | jq -r '.files[]?.path // empty')

  if (( ! TOUCHES_CI )); then
    SKIP_REASONS[$PR_NUM]="Does not modify CI workflows"
    continue
  fi

  # Check 4: Include/exclude filters
  FILTERED_OUT=0
  for pattern in "${INCLUDE_PATTERNS[@]:-}"; do
    if ! matches_pattern "$BRANCH $TITLE" "$pattern"; then
      FILTERED_OUT=1
      break
    fi
  done

  for pattern in "${EXCLUDE_PATTERNS[@]:-}"; do
    if matches_pattern "$BRANCH $TITLE" "$pattern"; then
      FILTERED_OUT=1
      break
    fi
  done

  if (( FILTERED_OUT )); then
    SKIP_REASONS[$PR_NUM]="Filtered out by include/exclude patterns"
    continue
  fi

  # Check 5: Only failing (if enabled)
  if (( ONLY_FAILING )); then
    CHECKS_JSON=$(gh pr checks "$PR_NUM" --repo "$REPO" --json conclusion 2>/dev/null || echo '[]')
    HAS_FAILURES=$(echo "$CHECKS_JSON" | jq -r '[.[] | select(.conclusion != "success")] | length')

    if [[ "$HAS_FAILURES" == "0" ]]; then
      SKIP_REASONS[$PR_NUM]="All checks passing (--only-failing active)"
      continue
    fi
  fi

  # Passed all checks - add to candidates
  CANDIDATES[$PR_NUM]="$BRANCH"
done

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Report Phase
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "DISCOVERY REPORT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if (( ${#CANDIDATES[@]} == 0 )); then
  warn "No candidate PRs found"

  if (( ${#SKIP_REASONS[@]} > 0 )); then
    echo ""
    echo "Skipped PRs:"
    for PR_NUM in "${!SKIP_REASONS[@]}"; do
      echo "  #${PR_NUM}: ${SKIP_REASONS[$PR_NUM]}"
    done
  fi

  exit 0
fi

success "Found ${#CANDIDATES[@]} candidate PR(s) for rebase:"
echo ""

# Print candidates table
printf "%-6s %-40s %-30s\n" "PR" "BRANCH" "TITLE"
echo "────────────────────────────────────────────────────────────────────────────"
for PR_NUM in "${!CANDIDATES[@]}"; do
  BRANCH="${CANDIDATES[$PR_NUM]}"
  TITLE="${PR_TITLES[$PR_NUM]}"
  # Truncate title if too long
  TITLE_SHORT="${TITLE:0:28}"
  [[ "${#TITLE}" -gt 28 ]] && TITLE_SHORT="${TITLE_SHORT}.."
  printf "%-6s %-40s %-30s\n" "#$PR_NUM" "$BRANCH" "$TITLE_SHORT"
done
echo ""

if (( ${#SKIP_REASONS[@]} > 0 )); then
  info "Skipped ${#SKIP_REASONS[@]} PR(s) (use -v for details)"
fi

# Exit if in report mode
if [[ "$MODE" == "report" ]]; then
  echo ""
  info "Run with --rebase to perform rebase operations"
  exit 0
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Rebase Phase
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "REBASE PHASE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Confirmation prompt
if (( ! FORCE )); then
  warn "About to rebase ${#CANDIDATES[@]} branch(es) onto ${BASE}"
  echo ""
  read -q "?Continue? [y/N] " || {
    echo ""
    info "Aborted by user"
    exit 1
  }
  echo ""
fi

# Check for clean working tree
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
  error "Working tree has uncommitted changes. Commit or stash first."
fi

# Fetch base branch
info "Fetching $BASE..."
git fetch "$(echo "$BASE" | cut -d/ -f1)" "$(echo "$BASE" | cut -d/ -f2-)" || error "Failed to fetch $BASE"

# Initialize state file
STATE_JSON='{"started":"'$(date -Iseconds)'","base":"'$BASE'","results":{}}'
echo "$STATE_JSON" > "$STATE_FILE"

# Track results
declare -A RESULTS  # PR_NUM => OK|CONFLICT|FAIL

# Process each candidate
for PR_NUM in "${!CANDIDATES[@]}"; do
  BRANCH="${CANDIDATES[$PR_NUM]}"
  TITLE="${PR_TITLES[$PR_NUM]}"

  echo ""
  echo "────────────────────────────────────────────────────────"
  echo "PR #$PR_NUM: $BRANCH"
  echo "$TITLE"
  echo "────────────────────────────────────────────────────────"

  # Fetch branch
  info "Fetching $BRANCH..."
  if ! git fetch origin "$BRANCH" 2>&1; then
    warn "Failed to fetch $BRANCH"
    RESULTS[$PR_NUM]="FAIL|fetch-failed"
    continue
  fi

  # Checkout branch
  info "Checking out $BRANCH..."
  if ! git checkout -B "$BRANCH" "origin/$BRANCH" 2>&1; then
    warn "Failed to checkout $BRANCH"
    RESULTS[$PR_NUM]="FAIL|checkout-failed"
    continue
  fi

  # Create backup
  BACKUP_REF="backup/pre-rebase-${BRANCH//\//-}-$(date +%Y%m%d%H%M%S)"
  git branch -f "$BACKUP_REF" HEAD
  info "Created backup: $BACKUP_REF"

  # Perform rebase
  info "Rebasing onto $BASE..."
  set +e
  REBASE_OUTPUT=$(git rebase "$BASE" 2>&1)
  REBASE_EXIT=$?
  set -e

  if [[ $REBASE_EXIT -ne 0 ]]; then
    warn "Rebase conflict on $BRANCH"
    echo "$REBASE_OUTPUT" | head -20

    # Abort rebase
    git rebase --abort 2>/dev/null || true

    # Restore original state
    git checkout -B "$BRANCH" "origin/$BRANCH" 2>/dev/null || true

    warn "Left backup at $BACKUP_REF for manual resolution"
    RESULTS[$PR_NUM]="CONFLICT|needs-manual-resolution"
    continue
  fi

  # Push with force-with-lease
  info "Pushing to origin/$BRANCH..."
  set +e
  PUSH_OUTPUT=$(git push --force-with-lease origin "$BRANCH" 2>&1)
  PUSH_EXIT=$?
  set -e

  if [[ $PUSH_EXIT -ne 0 ]]; then
    warn "Failed to push $BRANCH"
    echo "$PUSH_OUTPUT" | head -10

    # Check if it's a permission issue
    if echo "$PUSH_OUTPUT" | grep -q "protected\|permission\|403"; then
      warn "Branch appears to be protected or lacks push permission"
      RESULTS[$PR_NUM]="FAIL|protected-branch"
    else
      RESULTS[$PR_NUM]="FAIL|push-failed"
    fi
    continue
  fi

  success "Rebased and pushed: $BRANCH"
  RESULTS[$PR_NUM]="OK"

  # Update state file
  STATE_JSON=$(cat "$STATE_FILE" | jq ".results[\"$PR_NUM\"] = {\"status\":\"OK\",\"branch\":\"$BRANCH\",\"timestamp\":\"$(date -Iseconds)\"}")
  echo "$STATE_JSON" > "$STATE_FILE"
done

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Final Summary
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

SUCCESS_COUNT=0
CONFLICT_COUNT=0
FAIL_COUNT=0

for PR_NUM in "${!RESULTS[@]}"; do
  RESULT="${RESULTS[$PR_NUM]}"
  STATUS="${RESULT%%|*}"
  REASON="${RESULT#*|}"
  BRANCH="${CANDIDATES[$PR_NUM]}"

  case "$STATUS" in
    OK)
      echo "✅ OK      PR #$PR_NUM ($BRANCH)"
      ((SUCCESS_COUNT++))
      ;;
    CONFLICT)
      echo "⚠️  CONFLICT PR #$PR_NUM ($BRANCH) - $REASON"
      ((CONFLICT_COUNT++))
      ;;
    FAIL)
      echo "❌ FAIL    PR #$PR_NUM ($BRANCH) - $REASON"
      ((FAIL_COUNT++))
      ;;
  esac
done

echo ""
echo "Results: $SUCCESS_COUNT succeeded, $CONFLICT_COUNT conflicts, $FAIL_COUNT failed"

if (( CONFLICT_COUNT > 0 || FAIL_COUNT > 0 )); then
  echo ""
  warn "Some PRs require manual intervention"
  echo "State file saved to: $STATE_FILE"
  exit 1
fi

success "All rebases completed successfully!"
exit 0
