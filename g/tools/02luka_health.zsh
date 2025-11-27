#!/usr/bin/env zsh
# ═══════════════════════════════════════════════════════════════════════
# 02luka System Health Check
# ═══════════════════════════════════════════════════════════════════════
# Comprehensive health check for all 02luka system components
# Usage: g/tools/02luka_health.zsh
# Output: JSON report to g/reports/health/health_YYYYMMDD.json
# ═══════════════════════════════════════════════════════════════════════

set -euo pipefail

# ═══════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════
ROOT="${HOME}/02luka"
TIMESTAMP=$(date +"%Y-%m-%dT%H:%M:%S%z")
HEALTH_LOG="${ROOT}/logs/health_monitor.log"
HEALTH_REPORT="${ROOT}/g/reports/health/health_$(date +%Y%m%d).json"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

# Create report directory
mkdir -p "$(dirname "$HEALTH_REPORT")"
mkdir -p "$(dirname "$HEALTH_LOG")"

# Start JSON report
echo "{" > "$HEALTH_REPORT"
echo "  \"timestamp\": \"$TIMESTAMP\"," >> "$HEALTH_REPORT"
echo "  \"checks\": [" >> "$HEALTH_REPORT"

# Helper: Run check and log result
run_check() {
  local name="$1"
  local command="$2"
  local expected="${3:-0}"

  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

  echo -n "Checking $name... "

  local result=0
  eval "$command" >/dev/null 2>&1 || result=$?

  # Treat SIGPIPE (141) as success for grep commands
  if [[ $result -eq 141 ]]; then
    result=0
  fi

  if [[ $result -eq $expected ]]; then
    echo -e "${GREEN}✓${NC}"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    echo "    {\"name\": \"$name\", \"status\": \"pass\", \"timestamp\": \"$TIMESTAMP\"}," >> "$HEALTH_REPORT"
  else
    echo -e "${RED}✗${NC} (exit code: $result)"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
    echo "    {\"name\": \"$name\", \"status\": \"fail\", \"exit_code\": $result, \"timestamp\": \"$TIMESTAMP\"}," >> "$HEALTH_REPORT"
  fi
}

echo ""
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║            🔍 02luka System Health Check                         ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo "📅 Time: $TIMESTAMP"
echo ""

# === Core Services ===
echo "📦 Core Services:"
run_check "Scanner LaunchAgent" "launchctl list | grep -q com.02luka.localtruth"
run_check "Autopilot LaunchAgent" "launchctl list | grep -q com.02luka.autopilot"
run_check "WO Executor LaunchAgent" "launchctl list | grep -q com.02luka.wo_executor"
run_check "JSON WO Processor" "launchctl list | grep -q com.02luka.json_wo_processor"
run_check "CLC Worker" "launchctl list | grep -q com.02luka.clc-worker"
run_check "Mary Bridge" "launchctl list | grep -q com.02luka.mary-bridge"
run_check "Shell Executor" "launchctl list | grep -q com.02luka.shell-executor"
run_check "OPAL Health v2" "launchctl list | grep -q com.02luka.opal-healthv2"
run_check "GMX CLC Orchestrator" "launchctl list | grep -q com.02luka.gmx-clc-orchestrator"

echo ""
echo "🤖 AI Services:"
run_check "Ollama installed" "command -v ollama"
run_check "Ollama running" "curl -s http://localhost:11434/api/tags >/dev/null"
run_check "Redis running" "redis-cli -a gggclukaic ping 2>/dev/null | grep -q PONG"

echo ""
echo "📊 Applications:"
run_check "Dashboard files exist" "test -f ${ROOT}/g/apps/dashboard/index.html"
run_check "OPAL API server" "curl -s http://127.0.0.1:7001/api/budget >/dev/null"

echo ""
echo "🗂️ Data Integrity:"
run_check "Expense ledger exists" "test -f ${ROOT}/g/apps/expense/ledger_2025.jsonl"
run_check "MLS lessons exist" "test -f ${ROOT}/g/knowledge/mls_lessons.jsonl"
run_check "Health telemetry exists" "test -f ${ROOT}/g/telemetry/health_check_latest.json"

echo ""
echo "🔧 Tools:"
run_check "Agent status tool" "test -x ${ROOT}/tools/agent_status.zsh"
run_check "OPAL health v2" "test -x ${ROOT}/g/tools/opal_health_check_v2.zsh"
run_check "GMX orchestrator" "test -x ${ROOT}/g/tools/gmx_clc_orchestrator.zsh"
run_check "RAM check tool" "test -x ${ROOT}/bin/check-ram"
run_check "Clear mem tool" "test -x ${ROOT}/bin/clear-mem"

echo ""
echo "💾 Storage:"
run_check "Main disk space >10GB" "test $(df -g ~/ | tail -1 | awk '{print $4}') -gt 10"
run_check "Lukadata mounted" "test -d /Volumes/lukadata"
run_check "Lukadata space >50GB" "test $(df -g /Volumes/lukadata | tail -1 | awk '{print $4}') -gt 50"

# Close JSON report
sed -i '' '$ s/,$//' "$HEALTH_REPORT"  # Remove trailing comma
echo "  ]," >> "$HEALTH_REPORT"
echo "  \"summary\": {" >> "$HEALTH_REPORT"
echo "    \"total\": $TOTAL_CHECKS," >> "$HEALTH_REPORT"
echo "    \"passed\": $PASSED_CHECKS," >> "$HEALTH_REPORT"
echo "    \"failed\": $FAILED_CHECKS," >> "$HEALTH_REPORT"
echo "    \"success_rate\": \"$((PASSED_CHECKS * 100 / TOTAL_CHECKS))%\"" >> "$HEALTH_REPORT"
echo "  }" >> "$HEALTH_REPORT"
echo "}" >> "$HEALTH_REPORT"

# Summary
echo ""
echo "╔═══════════════════════════════════════════════════════════════════╗"
if [[ $FAILED_CHECKS -eq 0 ]]; then
  echo "║  ✅ OVERALL STATUS: HEALTHY                                       ║"
else
  echo "║  ⚠️  OVERALL STATUS: ISSUES DETECTED                               ║"
fi
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""
echo "Total checks: $TOTAL_CHECKS"
echo -e "Passed: ${GREEN}$PASSED_CHECKS${NC}"
echo -e "Failed: ${RED}$FAILED_CHECKS${NC}"
echo "Success rate: $((PASSED_CHECKS * 100 / TOTAL_CHECKS))%"
echo ""
echo "📄 Report saved: $HEALTH_REPORT"

# Log to main health log
echo "[$TIMESTAMP] Health check: $PASSED_CHECKS/$TOTAL_CHECKS passed ($((PASSED_CHECKS * 100 / TOTAL_CHECKS))%)" >> "$HEALTH_LOG"

# Exit with failure if any check failed
if [[ $FAILED_CHECKS -gt 0 ]]; then
  echo -e "${YELLOW}⚠️  System has issues - review failed checks${NC}"
  exit 1
else
  echo -e "${GREEN}✅ All systems operational${NC}"
  exit 0
fi

