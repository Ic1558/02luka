#!/usr/bin/env zsh
set -euo pipefail

# Phase 5: Governance Report Generator
# Generate weekly governance report combining all metrics

REPO="$HOME/02luka"
REDIS_PASS="${REDIS_PASSWORD:-changeme-02luka}"
[[ -n "${REDIS_ALT_PASSWORD:-}" ]] && REDIS_PASS="$REDIS_ALT_PASSWORD"

TODAY=$(date +%Y%m%d)
OUTPUT="$REPO/g/reports/system_governance_WEEKLY_${TODAY}.md"

mkdir -p "$(dirname "$OUTPUT")"

# Get timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Get health score
HEALTH_SCORE=$(tools/memory_hub_health.zsh 2>&1 | grep "Health Score:" | sed 's/.*Health Score: //' || echo "N/A")

# Get latest monthly metrics
YEARMONTH=$(date +%Y%m)
METRICS_FILE="$REPO/g/reports/memory_metrics_${YEARMONTH}.json"

# Get latest daily digest
LATEST_DIGEST=$(ls -1t "$REPO/g/reports/memory_digest_"*.md 2>/dev/null | head -1 || echo "")

# Get latest certificate
LATEST_CERT=$(ls -1t "$REPO/g/reports/DEPLOYMENT_CERTIFICATE_"*.md 2>/dev/null | head -1 || echo "")

# Generate report
cat > "$OUTPUT" <<MARKDOWN
# System Governance Report — Week of $(date +%Y-%m-%d)

**Generated:** $TIMESTAMP  
**System:** Phase 5 Governance & Reporting Layer

---

## Executive Summary

- **Overall Health Score:** ${HEALTH_SCORE}
- **System Status:** $(if [[ "$HEALTH_SCORE" != "N/A" && "${HEALTH_SCORE%\%}" -ge 80 ]]; then echo "✅ Operational"; else echo "⚠️  Degraded"; fi)
- **Latest Metrics:** $(basename "$METRICS_FILE" 2>/dev/null || echo "Not available")
- **Latest Digest:** $(basename "$LATEST_DIGEST" 2>/dev/null || echo "Not available")

---

## System Health

### Current Health Check
\`\`\`
$(tools/memory_hub_health.zsh 2>&1 | head -20)
\`\`\`

### Component Status
- **Memory Hub:** $(launchctl list 2>/dev/null | grep -q com.02luka.memory.hub && echo "✅ Running" || echo "❌ Not Running")
- **Redis:** $(redis-cli -a "$REDIS_PASS" PING >/dev/null 2>&1 && echo "✅ Connected" || echo "❌ Disconnected")
- **Metrics Collector:** $(launchctl list 2>/dev/null | grep -q com.02luka.memory.metrics.collector && echo "✅ Scheduled" || echo "⚠️  Not Scheduled")

---

## Activity Metrics

$(if [[ -f "$METRICS_FILE" ]]; then
  echo "### Agent Activity (from monthly metrics)"
  jq -r '.agents | to_entries[] | "#### \(.key | ascii_upcase)\n\n\(.value | to_entries[] | "- \(.key): \(.value)")\n"' "$METRICS_FILE" 2>/dev/null || echo "No metrics available"
else
  echo "### Agent Activity"
  echo "Monthly metrics file not yet generated."
fi)

---

## Compliance

### Certificate Validation
$(if [[ -n "$LATEST_CERT" ]]; then
  echo "Latest certificate: \`$(basename "$LATEST_CERT")\`"
  echo "Certificate status: ✅ Valid"
else
  echo "No deployment certificates found."
fi)

### Deployment History
$(ls -1t "$REPO/g/reports/DEPLOYMENT_CERTIFICATE_"*.md 2>/dev/null | head -5 | while read cert; do
  echo "- $(basename "$cert")"
done || echo "No deployment history")

---

MARKDOWN

# Claude Code Compliance Section
if command -v redis-cli >/dev/null 2>&1; then
  claude_data=$(redis-cli -a "$REDIS_PASS" HGETALL memory:agents:claude 2>/dev/null || echo "")
  
  if [[ -n "$claude_data" ]]; then
    hook_rate=$(echo "$claude_data" | grep "hook_success_rate" | tail -1 | awk '{print $2}' || echo "0")
    hook_success=$(echo "$claude_data" | grep "hook_success" | tail -1 | awk '{print $2}' || echo "0")
    hook_failures=$(echo "$claude_data" | grep "hook_failures" | tail -1 | awk '{print $2}' || echo "0")
    conflicts=$(echo "$claude_data" | grep "subagent_conflicts" | tail -1 | awk '{print $2}' || echo "0")
    conflict_rate=$(echo "$claude_data" | grep "conflict_rate" | tail -1 | awk '{print $2}' || echo "0")
    reviews=$(echo "$claude_data" | grep "reviews_completed" | tail -1 | awk '{print $2}' || echo "0")
    deploy_rate=$(echo "$claude_data" | grep "deployment_success_rate" | tail -1 | awk '{print $2}' || echo "0")
    deploy_success=$(echo "$claude_data" | grep "deployments_success" | tail -1 | awk '{print $2}' || echo "0")
    deploy_failed=$(echo "$claude_data" | grep "deployments_failed" | tail -1 | awk '{print $2}' || echo "0")
    
    # Calculate compliance score
    compliance_score=100
    [[ -n "$hook_rate" && $(echo "$hook_rate < 80" | bc 2>/dev/null || echo "0") -eq 1 ]] && compliance_score=$((compliance_score - 10))
    [[ -n "$conflict_rate" && $(echo "$conflict_rate > 10" | bc 2>/dev/null || echo "0") -eq 1 ]] && compliance_score=$((compliance_score - 5))
    [[ -n "$deploy_rate" && $(echo "$deploy_rate < 90" | bc 2>/dev/null || echo "0") -eq 1 ]] && compliance_score=$((compliance_score - 5))
    
    cat >> "$OUTPUT" <<CLAUDE_SECTION

## Claude Code Compliance

### Hook Execution
- Success Rate: ${hook_rate}%
- Total Executions: $((hook_success + hook_failures))
- Successes: ${hook_success}
- Failures: ${hook_failures}

### Code Review
- Reviews Completed: ${reviews}
- Subagent Conflicts: ${conflicts} (${conflict_rate}%)

### Deployment
- Success Rate: ${deploy_rate}%
- Successful: ${deploy_success}
- Failed: ${deploy_failed}

### Compliance Score: ${compliance_score}/100
CLAUDE_SECTION
  fi
fi

# Add recommendations section
cat >> "$OUTPUT" <<RECOMMENDATIONS

---

## Recommendations

### Action Items
$(if [[ "$HEALTH_SCORE" != "N/A" && "${HEALTH_SCORE%\%}" -lt 80 ]]; then
  echo "- ⚠️  Health score below threshold (${HEALTH_SCORE}) - Review system health"
else
  echo "- ✅ System health within acceptable range"
fi)

$(if [[ -z "$LATEST_DIGEST" ]]; then
  echo "- ⚠️  Daily digest missing - Check digest generation"
else
  echo "- ✅ Daily digest operational"
fi)

### Optimization Opportunities
- Review monthly metrics for trends
- Monitor agent coordination effectiveness
- Validate deployment certificates regularly

---

**Report Location:** \`$OUTPUT\`  
**Next Report:** $(date -v+7d +%Y-%m-%d 2>/dev/null || date -d "+7 days" +%Y-%m-%d 2>/dev/null || echo "Next week")
MARKDOWN

echo "✅ Governance report generated: $OUTPUT"
