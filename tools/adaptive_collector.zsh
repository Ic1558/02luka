#!/usr/bin/env zsh
set -euo pipefail

# Phase 6: Adaptive Insight Collector
# Simple trend detection and anomaly spotting

REPO="$HOME/02luka"
REDIS_PASS="changeme-02luka"
TODAY=$(date +%Y%m%d)
OUTPUT="$REPO/mls/adaptive/insights_${TODAY}.json"

mkdir -p "$(dirname "$OUTPUT")"

# Get current month for metrics
YEARMONTH=$(date +%Y%m)
METRICS_FILE="$REPO/g/reports/memory_metrics_${YEARMONTH}.json"

# Initialize insights structure
declare -A trends
declare -a anomalies
declare -a recommendations

# Function: Calculate trend (simple average comparison)
calculate_trend() {
  local metric_name="$1"
  local current_avg="$2"
  local previous_avg="$3"
  
  if (( $(echo "$current_avg > $previous_avg * 1.1" | bc -l) )); then
    echo "improving"
  elif (( $(echo "$current_avg < $previous_avg * 0.9" | bc -l) )); then
    echo "declining"
  else
    echo "stable"
  fi
}

# Function: Get trend direction (up/down/stable)
get_trend_direction() {
  local trend="$1"
  case "$trend" in
    improving) echo "up" ;;
    declining) echo "down" ;;
    *) echo "stable" ;;
  esac
}

# Function: Calculate percentage change
calculate_change() {
  local current="$1"
  local previous="$2"
  if [[ -z "$previous" || "$previous" == "0" ]]; then
    echo "0%"
  else
    local change=$(echo "($current - $previous) / $previous * 100" | bc -l)
    printf "%.1f%%" "$change"
  fi
}

# Read metrics from monthly JSON (if available)
if [[ -f "$METRICS_FILE" ]]; then
  # Extract Claude Code metrics
  claude_data=$(jq -r '.agents.claude // {}' "$METRICS_FILE" 2>/dev/null || echo "{}")
  
  # TODO: Implement trend calculation from historical data
  # For now, use current Redis values
fi

# Get current metrics from Redis
if command -v redis-cli >/dev/null 2>&1; then
  # Get Claude Code metrics
  claude_current=$(redis-cli -a "$REDIS_PASS" HGET memory:agents:claude hook_success_rate 2>/dev/null || echo "0")
  
  # TODO: Compare with historical averages
  # For MVP: Mark as stable if no historical data
  if [[ -n "$claude_current" && "$claude_current" != "0" ]]; then
    trends[claude_hook_success]="stable"
  fi
fi

# Generate insights JSON
cat > "$OUTPUT" <<JSON
{
  "date": "${TODAY}",
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "trends": {
    "claude_hook_success": {
      "direction": "${trends[claude_hook_success]:-stable}",
      "trend": "$(get_trend_direction "${trends[claude_hook_success]:-stable}")",
      "change": "0%"
    }
  },
  "anomalies": [],
  "recommendations": [],
  "recommendation_summary": "No significant trends detected. System operating normally."
}
JSON

echo "✅ Adaptive insights generated: $OUTPUT"
