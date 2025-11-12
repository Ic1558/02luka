#!/usr/bin/env zsh
set -euo pipefail

# Phase 5: Governance Self-Audit
# Automated compliance and audit checks

REPO="$HOME/02luka"
REDIS_PASS="${REDIS_PASSWORD:-changeme-02luka}"
[[ -n "${REDIS_ALT_PASSWORD:-}" ]] && REDIS_PASS="$REDIS_ALT_PASSWORD"

TODAY=$(date +%Y%m%d)
OUTPUT="$REPO/g/reports/phase5_governance/governance_audit_${TODAY}.md"

mkdir -p "$(dirname "$OUTPUT")"

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

SCORE=0
MAX_SCORE=0
issues=()

ok() { echo "✅ $1"; SCORE=$((SCORE+1)); MAX_SCORE=$((MAX_SCORE+1)); }
ng() { echo "❌ $1"; MAX_SCORE=$((MAX_SCORE+1)); issues+=("$1"); }

cat > "$OUTPUT" <<MARKDOWN
# Governance Self-Audit Report — $(date +%Y-%m-%d)

**Generated:** $TIMESTAMP  
**System:** Phase 5 Governance & Reporting Layer

---

## Audit Results

MARKDOWN

echo "=== Governance Self-Audit ===" >&2
echo "" >&2

# Phase 4 Components
echo "Phase 4 Components:" >&2
[[ -f "$REPO/agents/memory_hub/memory_hub.py" ]] && ok "Memory hub script exists" || ng "Memory hub script missing"
[[ -x "$REPO/tools/mary_memory_hook.zsh" ]] && ok "Mary hook executable" || ng "Mary hook not executable"
[[ -x "$REPO/tools/rnd_memory_hook.zsh" ]] && ok "R&D hook executable" || ng "R&D hook not executable"
[[ -f "$REPO/shared_memory/context.json" ]] && ok "Shared memory context exists" || ng "Shared memory context missing"
echo "" >&2

# Phase 5 Components
echo "Phase 5 Components:" >&2
[[ -x "$REPO/tools/memory_metrics_collector.zsh" ]] && ok "Metrics collector executable" || ng "Metrics collector not executable"
[[ -x "$REPO/tools/governance_report_generator.zsh" ]] && ok "Report generator executable" || ng "Report generator not executable"
[[ -x "$REPO/tools/governance_alert_hook.zsh" ]] && ok "Alert hook executable" || ng "Alert hook not executable"
[[ -x "$REPO/tools/certificate_validator.zsh" ]] && ok "Certificate validator executable" || ng "Certificate validator not executable"
[[ -x "$REPO/tools/governance_self_audit.zsh" ]] && ok "Self-audit script executable" || ng "Self-audit script not executable"
echo "" >&2

# LaunchAgents
echo "LaunchAgents:" >&2
launchctl list 2>/dev/null | grep -q com.02luka.memory.hub && ok "Memory hub LaunchAgent loaded" || ng "Memory hub LaunchAgent not loaded"
launchctl list 2>/dev/null | grep -q com.02luka.memory.metrics.collector && ok "Metrics collector LaunchAgent loaded" || ng "Metrics collector LaunchAgent not loaded"
launchctl list 2>/dev/null | grep -q com.02luka.governance.report.weekly && ok "Report generator LaunchAgent loaded" || ng "Report generator LaunchAgent not loaded"
launchctl list 2>/dev/null | grep -q com.02luka.governance.alerts && ok "Alert hook LaunchAgent loaded" || ng "Alert hook LaunchAgent not loaded"
launchctl list 2>/dev/null | grep -q com.02luka.certificate.validator && ok "Certificate validator LaunchAgent loaded" || ng "Certificate validator LaunchAgent not loaded"
launchctl list 2>/dev/null | grep -q com.02luka.governance.audit && ok "Self-audit LaunchAgent loaded" || ng "Self-audit LaunchAgent not loaded"
echo "" >&2

# Directories
echo "Required Directories:" >&2
[[ -d "$REPO/g/reports" ]] && ok "Reports directory exists" || ng "Reports directory missing"
[[ -d "$REPO/shared_memory" ]] && ok "Shared memory directory exists" || ng "Shared memory directory missing"
[[ -d "$REPO/logs" ]] && ok "Logs directory exists" || ng "Logs directory missing"
[[ -d "$REPO/bridge/memory" ]] && ok "Bridge memory directory exists" || ng "Bridge memory directory missing"
echo "" >&2

# Redis Connectivity
echo "Redis Connectivity:" >&2
if redis-cli -a "$REDIS_PASS" PING >/dev/null 2>&1; then
  ok "Redis connected"
else
  ng "Redis not connected"
fi
echo "" >&2

# Health Scores
echo "Health Scores:" >&2
HEALTH_OUTPUT=$(tools/memory_hub_health.zsh 2>&1 || echo "")
HEALTH_SCORE_RAW=$(echo "$HEALTH_OUTPUT" | grep "Health Score:" | sed 's/.*Health Score: //' || echo "N/A")

# Extract numeric value (handle formats like "92%", "92% (12/13)", "N/A")
if [[ "$HEALTH_SCORE_RAW" == "N/A" ]]; then
  ng "Health score unavailable"
else
  # Extract first number before % or space
  HEALTH_NUM=$(echo "$HEALTH_SCORE_RAW" | grep -oE '^[0-9]+' | head -1 || echo "0")
  if [[ -n "$HEALTH_NUM" && "$HEALTH_NUM" -ge 80 ]]; then
    ok "Health score acceptable (${HEALTH_NUM}%)"
  else
    ng "Health score below threshold (${HEALTH_SCORE_RAW})"
  fi
fi
echo "" >&2

# Calculate compliance score
if [[ $MAX_SCORE -gt 0 ]]; then
  COMPLIANCE_SCORE=$((SCORE * 100 / MAX_SCORE))
else
  COMPLIANCE_SCORE=0
fi

# Append results to report
{
  echo "### Component Checks"
  echo ""
  echo "**Total Checks:** $MAX_SCORE"  
  echo "**Passed:** $SCORE"
  echo "**Failed:** $((MAX_SCORE - SCORE))"
  echo ""
  echo "### Compliance Score: ${COMPLIANCE_SCORE}/100"
  echo ""
  
  if [[ ${#issues[@]} -gt 0 ]]; then
    echo "### Issues Found"
    echo ""
    for issue in "${issues[@]}"; do
      echo "- ❌ $issue"
    done
    echo ""
  fi
  
  echo "### Recommendations"
  echo ""
  if [[ $COMPLIANCE_SCORE -ge 90 ]]; then
    echo "- ✅ System compliance is excellent"
  elif [[ $COMPLIANCE_SCORE -ge 80 ]]; then
    echo "- ⚠️  System compliance is good but could be improved"
  else
    echo "- ❌ System compliance needs attention"
  fi
  
  echo ""
  echo "---"
  echo ""
  echo "**Report Location:** \`$OUTPUT\`"
} >> "$OUTPUT"

echo "✅ Self-audit complete: $OUTPUT" >&2
echo "   Compliance Score: ${COMPLIANCE_SCORE}/100" >&2
