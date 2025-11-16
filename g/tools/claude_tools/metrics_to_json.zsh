#!/usr/bin/env zsh
# Metrics to JSON Generator
# Purpose: Generate JSON metrics file from logs and metrics data
# Usage: metrics_to_json.zsh [YYYYMM]
# Output: g/reports/claude_code_metrics_YYYYMM.json

set -euo pipefail

BASE="${LUKA_SOT:-$HOME/02luka}"
MONTH="${1:-$(date +%Y%m)}"
OUTPUT_JSON="$BASE/g/reports/claude_code_metrics_${MONTH}.json"
LOG_DIR="$BASE/logs"

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" >&2
}

log "📊 Generating metrics JSON for $MONTH..."

# Initialize counters
HOOK_SUCCESS=0
HOOK_FAILURES=0
SUBAGENT_REVIEWS=0
SUBAGENT_COMPETES=0
DEPLOYMENTS_SUCCESS=0
DEPLOYMENTS_FAILED=0

# Count hook executions from logs (last 30 days)
if [[ -f "$LOG_DIR/claude_hooks.log" ]]; then
  HOOK_SUCCESS=$(grep -c "✅" "$LOG_DIR/claude_hooks.log" 2>/dev/null || echo "0")
  HOOK_FAILURES=$(grep -c "❌" "$LOG_DIR/claude_hooks.log" 2>/dev/null || echo "0")
fi

# Count subagent usage from metrics log
if [[ -f "$LOG_DIR/subagent_metrics.log" ]]; then
  SUBAGENT_REVIEWS=$(grep -c "strategy=review" "$LOG_DIR/subagent_metrics.log" 2>/dev/null || echo "0")
  SUBAGENT_COMPETES=$(grep -c "strategy=compete" "$LOG_DIR/subagent_metrics.log" 2>/dev/null || echo "0")
fi

# Count deployments from logs
if [[ -f "$LOG_DIR/claude_deployments.log" ]]; then
  DEPLOYMENTS_SUCCESS=$(grep -c "✅.*deployment.*success\|✅.*Deployment.*complete" "$LOG_DIR/claude_deployments.log" 2>/dev/null || echo "0")
  DEPLOYMENTS_FAILED=$(grep -c "❌.*deployment.*failed\|❌.*Deployment.*failed" "$LOG_DIR/claude_deployments.log" 2>/dev/null || echo "0")
fi

# Calculate rates
TOTAL_HOOKS=$((HOOK_SUCCESS + HOOK_FAILURES))
HOOK_SUCCESS_RATE=0
if [[ $TOTAL_HOOKS -gt 0 ]]; then
  HOOK_SUCCESS_RATE=$(printf '%.2f' "$(echo "$HOOK_SUCCESS $TOTAL_HOOKS" | awk '{printf ($1/$2)*100}')")
fi

TOTAL_DEPLOYMENTS=$((DEPLOYMENTS_SUCCESS + DEPLOYMENTS_FAILED))
DEPLOYMENT_SUCCESS_RATE=0
if [[ $TOTAL_DEPLOYMENTS -gt 0 ]]; then
  DEPLOYMENT_SUCCESS_RATE=$(printf '%.2f' "$(echo "$DEPLOYMENTS_SUCCESS $TOTAL_DEPLOYMENTS" | awk '{printf ($1/$2)*100}')")
fi

TOTAL_SUBAGENTS=$((SUBAGENT_REVIEWS + SUBAGENT_COMPETES))

# Generate JSON
TMP_JSON="${OUTPUT_JSON}.tmp"
{
  echo "{"
  echo "  \"month\": \"$MONTH\","
  echo "  \"generated_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
  echo "  \"hooks\": {"
  echo "    \"success\": $HOOK_SUCCESS,"
  echo "    \"failures\": $HOOK_FAILURES,"
  echo "    \"total\": $TOTAL_HOOKS,"
  echo "    \"success_rate\": $HOOK_SUCCESS_RATE"
  echo "  },"
  echo "  \"subagents\": {"
  echo "    \"reviews\": $SUBAGENT_REVIEWS,"
  echo "    \"competes\": $SUBAGENT_COMPETES,"
  echo "    \"total\": $TOTAL_SUBAGENTS"
  echo "  },"
  echo "  \"deployments\": {"
  echo "    \"success\": $DEPLOYMENTS_SUCCESS,"
  echo "    \"failed\": $DEPLOYMENTS_FAILED,"
  echo "    \"total\": $TOTAL_DEPLOYMENTS,"
  echo "    \"success_rate\": $DEPLOYMENT_SUCCESS_RATE"
  echo "  }"
  echo "}"
} > "$TMP_JSON"

# Validate JSON
if command -v jq >/dev/null 2>&1; then
  if jq . "$TMP_JSON" >/dev/null 2>&1; then
    mv "$TMP_JSON" "$OUTPUT_JSON"
    log "✅ JSON generated: $OUTPUT_JSON"
    
    # Display summary
    echo ""
    echo "Metrics Summary:"
    jq -r '
      "  Hooks: \(.hooks.success)/\(.hooks.total) (\(.hooks.success_rate)%)",
      "  Subagents: \(.subagents.total) total (\(.subagents.reviews) reviews, \(.subagents.competes) competes)",
      "  Deployments: \(.deployments.success)/\(.deployments.total) (\(.deployments.success_rate)%)"
    ' "$OUTPUT_JSON"
  else
    log "❌ Invalid JSON generated"
    rm -f "$TMP_JSON"
    exit 1
  fi
else
  # Fallback: move without validation if jq not available
  mv "$TMP_JSON" "$OUTPUT_JSON"
  log "⚠️  JSON generated without validation (jq not available): $OUTPUT_JSON"
fi

exit 0
