#!/usr/bin/env bash
set -euo pipefail

# CLS Performance Review Script
# Usage: bash scripts/run_cls_review.sh [--days N] [--notify]

DAYS=${1:-7}
NOTIFY=${2:-false}
REPORT="g/reports/cls_performance_$(date '+%Y%m%d_%H%M').md"
LOG="g/telemetry/cls_runs.ndjson"

echo "=== CLS Performance Review (last $DAYS days) ==="
echo "📊 Generating performance report..."
echo "📁 Report: $REPORT"
echo "📈 Telemetry: $LOG"

# Create reports directory if it doesn't exist
mkdir -p g/reports

# Generate the performance report
node agents/reflection/self_review.cjs --agent cls --days "$DAYS" > "$REPORT"

# Insert metrics into knowledge base
if [ -f "knowledge/index.cjs" ]; then
  echo "💾 Inserting metrics into knowledge base..."
  node knowledge/index.cjs --insert-metrics "$REPORT"
fi

echo "✅ CLS performance report generated at $REPORT"

# Optional notification
if [ "$NOTIFY" = "--notify" ]; then
  echo "📢 Sending notification..."
  # Add Discord notification here if needed
fi

echo "🎯 CLS Performance Review Complete"
