#!/usr/bin/env zsh
# Daily metrics collector for Mary/CLS
# Collects: processed, quarantined, pending, avg process time, 95p latency
# Runs at 00:05 daily
set -euo pipefail

REPO="$HOME/02luka"
DATE=$(date +%Y%m%d)
YEARMONTH=$(date +%Y%m)
METRICS_DIR="$REPO/g/reports/mary_metrics_${YEARMONTH}"
METRICS_FILE="$METRICS_DIR/mary_metrics_${DATE}.json"
README_FILE="$METRICS_DIR/README.md"
MARY_LOG="$REPO/logs/mary_dispatcher.log"
CLS_LOG="$REPO/logs/cls_cmdin_worker.jsonl"

mkdir -p "$METRICS_DIR"

# Initialize metrics
declare -A metrics
metrics[mary_processed]=0
metrics[mary_quarantined]=0
metrics[mary_pending]=0
metrics[cls_processed]=0
metrics[cls_errors]=0
metrics[avg_process_time_ms]=0
metrics[p95_latency_ms]=0

# Collect Mary metrics (from log)
if [[ -f "$MARY_LOG" ]]; then
  # Count processed (today)
  metrics[mary_processed]=$(grep "$(date +%Y-%m-%d)" "$MARY_LOG" 2>/dev/null | grep -c "PROCESSED" || echo "0")
  
  # Count quarantined (today)
  metrics[mary_quarantined]=$(grep "$(date +%Y-%m-%d)" "$MARY_LOG" 2>/dev/null | grep -c "QUARANTINED" || echo "0")
fi

# Count pending (current)
metrics[mary_pending]=$(find "$REPO/bridge/inbox/ENTRY" -maxdepth 1 -name "*.yaml" 2>/dev/null | wc -l | xargs || echo "0")

# Collect CLS metrics (from JSONL)
if [[ -f "$CLS_LOG" ]]; then
  # Count processed (today)
  today=$(date +%Y-%m-%d)
  metrics[cls_processed]=$(grep "$today" "$CLS_LOG" 2>/dev/null | jq -r 'select(.event == "ok")' | wc -l | xargs || echo "0")
  
  # Count errors (today)
  metrics[cls_errors]=$(grep "$today" "$CLS_LOG" 2>/dev/null | jq -r 'select(.event == "error")' | wc -l | xargs || echo "0")
fi

# Calculate process times (simplified - would need timing data in logs)
# For now, use placeholder values
metrics[avg_process_time_ms]=0
metrics[p95_latency_ms]=0

# Write JSON metrics
cat > "$METRICS_FILE" <<JSON
{
  "date": "${DATE}",
  "timestamp": "$(date -u +%FT%TZ)",
  "metrics": {
    "mary": {
      "processed": ${metrics[mary_processed]},
      "quarantined": ${metrics[mary_quarantined]},
      "pending": ${metrics[mary_pending]}
    },
    "cls": {
      "processed": ${metrics[cls_processed]},
      "errors": ${metrics[cls_errors]}
    },
    "performance": {
      "avg_process_time_ms": ${metrics[avg_process_time_ms]},
      "p95_latency_ms": ${metrics[p95_latency_ms]}
    }
  }
}
JSON

# Update README
if [[ ! -f "$README_FILE" ]]; then
  cat > "$README_FILE" <<MD
# Mary/CLS Metrics - ${YEARMONTH}

Daily metrics for Mary Dispatcher and CLS Self-Bridge.

## Files

- \`mary_metrics_YYYYMMDD.json\` - Daily metrics (JSON)
- \`README.md\` - This file

## Metrics

- **mary.processed**: WOs processed by Mary
- **mary.quarantined**: WOs quarantined by Mary
- **mary.pending**: WOs pending in ENTRY inbox
- **cls.processed**: .do files processed by CLS
- **cls.errors**: .do files with errors
- **performance.avg_process_time_ms**: Average processing time
- **performance.p95_latency_ms**: 95th percentile latency

## Generated

$(date -u +%FT%TZ)
MD
fi

echo "$(date +%FT%TZ) Metrics collected: ${DATE}" >> "$REPO/logs/mary_metrics.log"
