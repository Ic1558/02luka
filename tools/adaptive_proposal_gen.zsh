#!/usr/bin/env zsh
set -euo pipefail

# Phase 6: Auto-Proposal Generator
# Generate R&D proposals from adaptive insights

REPO="$HOME/02luka"
TODAY=$(date +%Y%m%d)
INSIGHTS_FILE="$REPO/mls/adaptive/insights_${TODAY}.json"
RND_INBOX="$REPO/bridge/inbox/RND"

mkdir -p "$RND_INBOX"

# Guard: Check if insights file exists
if [[ ! -f "$INSIGHTS_FILE" ]]; then
  echo "⚠️  No insights file found. Run adaptive_collector.zsh first."
  exit 0
fi

# Guard: Check if we already generated a proposal today
if [[ -f "$RND_INBOX/RND-ADAPTIVE-${TODAY}-"*.yaml ]]; then
  echo "ℹ️  Proposal already generated today. Skipping."
  exit 0
fi

# Read insights
trends=$(jq -r '.trends // {}' "$INSIGHTS_FILE" 2>/dev/null || echo "{}")
anomalies=$(jq -r '.anomalies // []' "$INSIGHTS_FILE" 2>/dev/null || echo "[]")
recommendations=$(jq -r '.recommendations // []' "$INSIGHTS_FILE" 2>/dev/null || echo "[]")

# Guard: Require ≥3 data points (samples) - check if we have enough historical data
# For MVP: Skip if no anomalies and no declining trends
has_declining=false
if echo "$trends" | jq -e '.[] | select(.direction == "declining")' >/dev/null 2>&1; then
  has_declining=true
fi

has_anomalies=false
if echo "$anomalies" | jq -e 'length > 0' >/dev/null 2>&1; then
  has_anomalies=true
fi

# Only generate proposal if we have actionable insights
if [[ "$has_declining" == "false" && "$has_anomalies" == "false" ]]; then
  echo "ℹ️  No actionable insights. Skipping proposal generation."
  exit 0
fi

# Generate R&D proposal
PROPOSAL_ID="RND-ADAPTIVE-${TODAY}-$(date +%H%M%S)"
PROPOSAL_FILE="$RND_INBOX/${PROPOSAL_ID}.yaml"

cat > "$PROPOSAL_FILE" <<YAML
id: ${PROPOSAL_ID}
type: adaptive_insight
generated_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
source: adaptive_collector

issue:
  description: "Adaptive insights detected issues requiring attention"
  trends: ${trends}
  anomalies: ${anomalies}

suggestion: |
  Review adaptive insights and address declining metrics or anomalies.
  Recommendations:
  $(echo "$recommendations" | jq -r '.[]' | sed 's/^/  - /')

risk: low
auto_generated: true
priority: medium

metadata:
  insights_file: ${INSIGHTS_FILE}
  sample_count: "TODO: Add sample count check"
YAML

echo "✅ R&D proposal generated: $PROPOSAL_FILE"
