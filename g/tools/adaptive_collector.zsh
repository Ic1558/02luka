#!/usr/bin/env zsh
set -euo pipefail

# Phase 6: Adaptive Insight Collector
# Simple trend detection and anomaly spotting

REPO="$HOME/02luka"
REDIS_PASS="${REDIS_PASSWORD:-changeme-02luka}"
[[ -n "${REDIS_ALT_PASSWORD:-}" ]] && REDIS_PASS="$REDIS_ALT_PASSWORD"

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
  
  if [[ -z "$previous_avg" || "$previous_avg" == "0" ]]; then
    echo "stable"  # No historical data
    return
  fi
  
  if (( $(echo "$current_avg > $previous_avg * 1.1" | bc -l 2>/dev/null || echo "0") )); then
    echo "improving"
  elif (( $(echo "$current_avg < $previous_avg * 0.9" | bc -l 2>/dev/null || echo "0") )); then
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
    local change=$(echo "($current - $previous) / $previous * 100" | bc -l 2>/dev/null || echo "0")
    printf "%.1f%%" "$change"
  fi
}

# Guard: Check if metrics file exists
if [[ ! -f "$METRICS_FILE" ]]; then
  echo "⚠️  Metrics file not found: $METRICS_FILE"
  echo "ℹ️  Generating minimal insights (no historical data)"
  
  # Generate minimal insights
  cat > "$OUTPUT" <<JSON
{
  "date": "${TODAY}",
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "trends": {},
  "anomalies": [],
  "recommendations": ["Collect more historical data for trend analysis"],
  "recommendation_summary": "Insufficient historical data. System operating normally."
}
JSON
  echo "✅ Adaptive insights generated (minimal): $OUTPUT"
  exit 0
fi

# Read current metrics from Redis
declare -A current_metrics
if command -v redis-cli >/dev/null 2>&1; then
  for agent in mary rnd claude; do
    agent_data=$(redis-cli -a "$REDIS_PASS" HGETALL memory:agents:${agent} 2>/dev/null || echo "")
    if [[ -n "$agent_data" && "$agent_data" != "NOAUTH"* && "$agent_data" != "AUTH failed"* ]]; then
      # Extract key metrics
      hook_success=$(echo "$agent_data" | grep -E "^hook_success_rate|^success_rate" | head -1 | cut -d' ' -f2 || echo "0")
      if [[ -n "$hook_success" && "$hook_success" != "0" ]]; then
        current_metrics[${agent}_hook_success]="$hook_success"
      fi
    fi
  done
fi

# Read historical metrics from JSON
declare -A historical_metrics
if command -v jq >/dev/null 2>&1; then
  # Extract agent metrics from monthly JSON
  for agent in mary rnd claude; do
    agent_data=$(jq -r ".agents.${agent} // {}" "$METRICS_FILE" 2>/dev/null || echo "{}")
    if [[ "$agent_data" != "{}" && "$agent_data" != "null" ]]; then
      hook_success=$(echo "$agent_data" | jq -r '.hook_success_rate // .success_rate // 0' 2>/dev/null || echo "0")
      if [[ -n "$hook_success" && "$hook_success" != "0" && "$hook_success" != "null" ]]; then
        historical_metrics[${agent}_hook_success]="$hook_success"
      fi
    fi
  done
fi

# Calculate trends
for metric_key in ${(k)current_metrics}; do
  current_val="${current_metrics[$metric_key]}"
  previous_val="${historical_metrics[$metric_key]:-}"
  
  if [[ -n "$previous_val" && "$previous_val" != "0" ]]; then
    trend=$(calculate_trend "$metric_key" "$current_val" "$previous_val")
    change=$(calculate_change "$current_val" "$previous_val")
    trends[$metric_key]="$trend|$change"
    
    # Detect anomalies (>2x or <0.5x)
    if (( $(echo "$current_val > $previous_val * 2" | bc -l 2>/dev/null || echo "0") )); then
      anomalies+=("{\"metric\":\"$metric_key\",\"value\":$current_val,\"expected\":$previous_val,\"severity\":\"high\"}")
    elif (( $(echo "$current_val < $previous_val * 0.5" | bc -l 2>/dev/null || echo "0") )); then
      anomalies+=("{\"metric\":\"$metric_key\",\"value\":$current_val,\"expected\":$previous_val,\"severity\":\"medium\"}")
    fi
  else
    # No historical data - mark as stable
    trends[$metric_key]="stable|0%"
  fi
done

# Generate recommendations
if [[ ${#anomalies[@]} -gt 0 ]]; then
  recommendations+=("Investigate metric anomalies detected in adaptive insights")
fi

for metric_key in ${(k)trends}; do
  trend_info="${trends[$metric_key]}"
  trend="${trend_info%%|*}"
  if [[ "$trend" == "declining" ]]; then
    recommendations+=("Monitor $metric_key - showing declining trend")
  fi
done

# Build trends JSON
trends_json="{"
first=true
for metric_key in ${(k)trends}; do
  trend_info="${trends[$metric_key]}"
  trend="${trend_info%%|*}"
  change="${trend_info##*|}"
  direction=$(get_trend_direction "$trend")
  
  if [[ "$first" == "true" ]]; then
    first=false
  else
    trends_json+=","
  fi
  trends_json+="\"$metric_key\":{\"direction\":\"$trend\",\"trend\":\"$direction\",\"change\":\"$change\"}"
done
trends_json+="}"

# Build anomalies JSON array
anomalies_json="["
first=true
for anomaly in "${anomalies[@]}"; do
  if [[ "$first" == "true" ]]; then
    first=false
  else
    anomalies_json+=","
  fi
  anomalies_json+="$anomaly"
done
anomalies_json+="]"

# Build recommendations array
recommendations_json="["
first=true
for rec in "${recommendations[@]}"; do
  if [[ "$first" == "true" ]]; then
    first=false
  else
    recommendations_json+=","
  fi
  recommendations_json+="\"$rec\""
done
recommendations_json+="]"

# Generate recommendation summary
if [[ ${#recommendations[@]} -gt 0 ]]; then
  summary="${recommendations[1]}"
else
  summary="No significant trends detected. System operating normally."
fi

# Generate insights JSON
cat > "$OUTPUT" <<JSON
{
  "date": "${TODAY}",
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "trends": ${trends_json},
  "anomalies": ${anomalies_json},
  "recommendations": ${recommendations_json},
  "recommendation_summary": "${summary}"
}
JSON

echo "✅ Adaptive insights generated: $OUTPUT"
