#!/usr/bin/env zsh
# GitHub Actions Cancellation Report
# Purpose: Analyze cancelled workflow runs and generate weekly report

set -euo pipefail

REPO="${LUKA_SOT:-$HOME/02luka}"
cd "$REPO"

# Get repo from git remote or use environment variable
GITHUB_REPO="${GITHUB_REPO:-}"
if [[ -z "$GITHUB_REPO" ]]; then
  # Try to extract from git remote
  REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
  if [[ "$REMOTE" =~ github\.com[:/]([^/]+/[^/]+) ]]; then
    GITHUB_REPO="${match[1]%.git}"
  else
    echo "❌ Cannot determine GitHub repo. Set GITHUB_REPO environment variable."
    exit 1
  fi
fi

SINCE="${SINCE:-7d}"  # Default: last 7 days
OUTPUT="${1:-g/reports/system/gha_cancellations_WEEKLY_$(date +%Y%m%d).json}"

mkdir -p "$(dirname "$OUTPUT")"

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" >&2
}

# Calculate cutoff date from SINCE (e.g., "7d" -> date 7 days ago)
# Support formats: "7d", "30d", "1w", "2w", etc.
CUTOFF_DATE=""
if [[ "$SINCE" =~ ^([0-9]+)d$ ]]; then
  DAYS="${match[1]}"
  # macOS date command
  if date -v-${DAYS}d +%Y-%m-%d >/dev/null 2>&1; then
    CUTOFF_DATE=$(date -v-${DAYS}d -u +%Y-%m-%dT%H:%M:%SZ)
  # GNU date command
  elif date -d "${DAYS} days ago" +%Y-%m-%d >/dev/null 2>&1; then
    CUTOFF_DATE=$(date -d "${DAYS} days ago" -u +%Y-%m-%dT%H:%M:%SZ)
  else
    log "⚠️  Cannot calculate date from SINCE=$SINCE, using all runs"
  fi
elif [[ "$SINCE" =~ ^([0-9]+)w$ ]]; then
  WEEKS="${match[1]}"
  DAYS=$((WEEKS * 7))
  if date -v-${DAYS}d +%Y-%m-%d >/dev/null 2>&1; then
    CUTOFF_DATE=$(date -v-${DAYS}d -u +%Y-%m-%dT%H:%M:%SZ)
  elif date -d "${DAYS} days ago" +%Y-%m-%d >/dev/null 2>&1; then
    CUTOFF_DATE=$(date -d "${DAYS} days ago" -u +%Y-%m-%dT%H:%M:%SZ)
  else
    log "⚠️  Cannot calculate date from SINCE=$SINCE, using all runs"
  fi
else
  log "⚠️  Unsupported SINCE format: $SINCE (expected format: 7d, 30d, 1w, etc.), using all runs"
fi

log "Fetching cancelled runs for $GITHUB_REPO (last $SINCE)..."

# Check if gh CLI is available
if ! command -v gh >/dev/null 2>&1; then
  log "❌ GitHub CLI (gh) not found. Install: brew install gh"
  exit 1
fi

# Check authentication
if ! gh auth status >/dev/null 2>&1; then
  log "⚠️  GitHub CLI not authenticated. Run: gh auth login"
  exit 1
fi

# Fetch cancelled runs
TMP=$(mktemp)
# Fetch runs and filter by cancellation status AND date (if CUTOFF_DATE is set)
if [[ -n "$CUTOFF_DATE" ]]; then
  # Filter by both cancellation status and date
  gh run list -R "$GITHUB_REPO" --limit 200 --json databaseId,displayTitle,conclusion,status,workflowName,createdAt,headBranch \
    --jq ".[] | select((.conclusion==\"cancelled\" or .status==\"cancelled\") and .createdAt >= \"$CUTOFF_DATE\")" > "$TMP" 2>/dev/null || {
    log "❌ Failed to fetch runs. Check GITHUB_REPO and authentication."
    rm -f "$TMP"
    exit 1
  }
else
  # Fallback: filter only by cancellation status (no date filtering)
  gh run list -R "$GITHUB_REPO" --limit 200 --json databaseId,displayTitle,conclusion,status,workflowName,createdAt,headBranch \
    --jq '.[] | select(.conclusion=="cancelled" or .status=="cancelled")' > "$TMP" 2>/dev/null || {
    log "❌ Failed to fetch runs. Check GITHUB_REPO and authentication."
    rm -f "$TMP"
    exit 1
  }
fi

# Analyze cancellations
log "Analyzing cancellations..."

# Group by workflow and generate summary
SUMMARY=$(jq -s '
  group_by(.workflowName) |
  map({
    workflow: .[0].workflowName,
    count: length,
    examples: (.[0:5] | map({
      title: .displayTitle,
      branch: .headBranch,
      createdAt: .createdAt,
      id: .databaseId
    }))
  }) |
  sort_by(-.count)
' "$TMP")

# Calculate totals
TOTAL=$(jq -s 'length' "$TMP")

# Generate report
REPORT=$(jq -n \
  --argjson summary "$SUMMARY" \
  --arg total "$TOTAL" \
  --arg repo "$GITHUB_REPO" \
  --arg since "$SINCE" \
  --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{
    generated_at: $generated_at,
    repo: $repo,
    period: $since,
    total_cancelled: ($total | tonumber),
    by_workflow: $summary,
    top_workflows: ($summary | .[0:5] | map({workflow: .workflow, count: .count}))
  }')

# Write report
echo "$REPORT" | jq '.' > "$OUTPUT"

log "✅ Report generated: $OUTPUT"
log "Total cancelled runs: $TOTAL"

# Print summary
echo ""
echo "== Cancellation Summary (last $SINCE) =="
echo "Total cancelled: $TOTAL"
echo ""
echo "Top workflows:"
jq -r '.by_workflow[0:5] | .[] | "  \(.workflow): \(.count) cancelled"' "$OUTPUT" || true

# Cleanup
rm -f "$TMP"

# Check if we should alert (threshold: >3 cancellations in a week)
if [[ "$TOTAL" -gt 3 ]]; then
  log "⚠️  High cancellation rate detected: $TOTAL cancelled runs"
  exit 1  # Exit with error to trigger alert hook
else
  log "✅ Cancellation rate within acceptable range"
  exit 0
fi
