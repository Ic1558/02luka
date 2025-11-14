#!/usr/bin/env zsh
set -euo pipefail

# Phase 6: Auto-Proposal Generator
# Generate R&D proposals from adaptive insights

REPO="$HOME/02luka"
TODAY=$(date +%Y%m%d)
INSIGHTS_FILE="$REPO/mls/adaptive/insights_${TODAY}.json"
RND_INBOX="$REPO/bridge/inbox/RND"
YEARMONTH=$(date +%Y%m)
METRICS_FILE="$REPO/g/reports/memory_metrics_${YEARMONTH}.json"

mkdir -p "$RND_INBOX"

# Guard: Check if insights file exists
if [[ ! -f "$INSIGHTS_FILE" ]]; then
  echo "⚠️  No insights file found. Run adaptive_collector.zsh first."
  exit 0
fi

# Guard: Check if we already generated a proposal today
setopt null_glob
existing_proposals=($RND_INBOX/RND-ADAPTIVE-${TODAY}-*.yaml)
unsetopt null_glob

if [[ ${#existing_proposals[@]} -gt 0 ]]; then
  echo "ℹ️  Proposal already generated today. Skipping."
  exit 0
fi

# Read insights
if ! command -v jq >/dev/null 2>&1; then
  echo "⚠️  jq not found. Cannot parse insights."
  exit 0
fi

trends=$(jq -r '.trends // {}' "$INSIGHTS_FILE" 2>/dev/null || echo "{}")
anomalies=$(jq -r '.anomalies // []' "$INSIGHTS_FILE" 2>/dev/null || echo "[]")
recommendations=$(jq -r '.recommendations // []' "$INSIGHTS_FILE" 2>/dev/null || echo "[]")

# Guard: Require ≥3 days with valid data points
# Count actual days with insights files (insights are generated daily)
sample_count=0
if [[ -d "$REPO/mls/adaptive" ]]; then
  # Count insights files from the past 30 days (reasonable window)
  # Each insights file represents one day of data collection
  setopt null_glob
  insights_files=($REPO/mls/adaptive/insights_*.json)
  unsetopt null_glob
  
  # Count valid insights files (exclude today's if it's the only one)
  for insight_file in "${insights_files[@]}"; do
    [[ -f "$insight_file" ]] || continue
    
    # Extract date from filename (insights_YYYYMMDD.json)
    file_date=$(basename "$insight_file" | grep -oE '[0-9]{8}' || echo "")
    if [[ -z "$file_date" ]]; then
      continue
    fi
    
    # Verify file has valid JSON structure (has date field)
    if command -v jq >/dev/null 2>&1; then
      if jq -e '.date' "$insight_file" >/dev/null 2>&1; then
        ((sample_count++))
      fi
    else
      # Fallback: if jq not available, count file existence
      ((sample_count++))
    fi
  done
fi

# Fallback: If no insights files but we have trends/anomalies, we have at least 1 day
# (from today's insights file that was just generated)
if [[ $sample_count -eq 0 ]] && ([[ "$trends" != "{}" ]] || [[ "$anomalies" != "[]" ]]); then
  sample_count=1
fi

# Guard: Require ≥3 days of data
if [[ $sample_count -lt 3 ]]; then
  echo "ℹ️  Insufficient historical data (have $sample_count days, need ≥3). Skipping proposal generation."
  exit 0
fi

# Check for actionable insights
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

# Extract specific metric context
metric_context=""
if [[ "$has_declining" == "true" ]]; then
  declining_metric=$(echo "$trends" | jq -r 'to_entries[] | select(.value.direction == "declining") | .key' | head -1)
  if [[ -n "$declining_metric" ]]; then
    metric_context="Declining metric: $declining_metric"
  fi
fi

if [[ "$has_anomalies" == "true" ]]; then
  anomaly_metric=$(echo "$anomalies" | jq -r '.[0].metric' 2>/dev/null || echo "")
  if [[ -n "$anomaly_metric" ]]; then
    metric_context="${metric_context:+$metric_context, }Anomaly detected: $anomaly_metric"
  fi
fi

cat > "$PROPOSAL_FILE" <<YAML
id: ${PROPOSAL_ID}
type: adaptive_insight
generated_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
source: adaptive_collector

issue:
  description: "Adaptive insights detected issues requiring attention"
  context: "${metric_context}"
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
  sample_count: ${sample_count}
  generated_by: adaptive_proposal_gen.zsh
YAML

echo "✅ R&D proposal generated: $PROPOSAL_FILE"
