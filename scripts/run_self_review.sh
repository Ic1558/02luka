#!/usr/bin/env bash
#
# run_self_review.sh - Self-Review Wrapper Script (Phase 7.1)
#
# Runs self-review engine, optionally sends Discord notification
#
# Usage:
#   bash scripts/run_self_review.sh [--days 7] [--notify]
#
# Environment:
#   DISCORD_WEBHOOK_DEFAULT - Discord webhook URL for notifications (optional)
#
# Exit codes:
#   0 - Success
#   1 - Self-review failed
#

set -euo pipefail

# Configuration
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SELF_REVIEW_SCRIPT="$REPO_ROOT/agents/reflection/self_review.cjs"
REPORTS_DIR="$REPO_ROOT/g/reports"

# Defaults
DAYS=7
NOTIFY=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --days)
      DAYS="$2"
      shift 2
      ;;
    --notify)
      NOTIFY=true
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [--days N] [--notify]"
      echo ""
      echo "Options:"
      echo "  --days N     Number of days to analyze (default: 7)"
      echo "  --notify     Send Discord notification (requires DISCORD_WEBHOOK_DEFAULT)"
      echo "  -h, --help   Show this help"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

echo "=== Self-Review Wrapper ==="
echo "Period: $DAYS days"
echo "Notify: $NOTIFY"
echo ""

# Run self-review
echo "Running self-review..."
if ! node "$SELF_REVIEW_SCRIPT" --days="$DAYS"; then
  echo "❌ Self-review failed" >&2
  exit 1
fi

echo ""

# Get latest report
LATEST_REPORT=$(ls -t "$REPORTS_DIR"/self_review_*.md 2>/dev/null | head -1)

if [ -z "$LATEST_REPORT" ]; then
  echo "⚠️  No report found - skipping notification"
  exit 0
fi

echo "📄 Latest report: $LATEST_REPORT"

# Discord notification (optional)
if [ "$NOTIFY" = true ]; then
  if [ -z "${DISCORD_WEBHOOK_DEFAULT:-}" ]; then
    echo "⚠️  DISCORD_WEBHOOK_DEFAULT not set - skipping notification"
  else
    echo "📢 Sending Discord notification..."

    # Extract summary from report
    SUMMARY=$(head -20 "$LATEST_REPORT" | grep -A 10 "## Summary" | head -11 || echo "Self-review complete")

    # Extract insights count
    INSIGHTS_COUNT=$(grep -c "^### [0-9]" "$LATEST_REPORT" || echo "0")

    # Build Discord message (first 3 lines of summary + insights count)
    MESSAGE="🤖 **Self-Review Complete** (${DAYS}d period)

$SUMMARY

**Insights Generated:** $INSIGHTS_COUNT

📄 Full report: \`${LATEST_REPORT##*/}\`"

    # Send to Discord
    if curl -X POST "${DISCORD_WEBHOOK_DEFAULT}" \
      -H "Content-Type: application/json" \
      -d "{\"content\": $(echo "$MESSAGE" | jq -Rs .)}" \
      --silent --show-error --fail \
      >/dev/null 2>&1; then
      echo "✅ Discord notification sent"
    else
      echo "⚠️  Discord notification failed (non-fatal)" >&2
    fi
  fi
fi

echo ""
echo "=== Self-Review Complete ==="
echo "Report: $LATEST_REPORT"
