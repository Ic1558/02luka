#!/usr/bin/env zsh
# System Health Monitor
# Runs daily smoke tests on all critical components
# Logs results for 7-day monitoring period

set -euo pipefail

# Config
HEALTH_LOG="${HOME}/02luka/logs/health_monitor.log"
HEALTH_REPORT="${HOME}/02luka/g/reports/health/health_$(date +%Y%m%d).json"
TIMESTAMP=$(date +"%Y-%m-%dT%H:%M:%S%z")

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
echo "=== 02luka System Health Check ==="
echo "Time: $TIMESTAMP"
echo ""

# === Core Services ===
echo "📦 Core Services:"
run_check "Scanner LaunchAgent" "launchctl list | grep -q com.02luka.localtruth"
run_check "Autopilot LaunchAgent" "launchctl list | grep -qE 'com\.02luka\.(rnd\.)?autopilot'"
run_check "WO Executor LaunchAgent" "launchctl list | grep -q com.02luka.wo_executor"
run_check "JSON WO Processor" "launchctl list | grep -q com.02luka.json_wo_processor"

echo ""
echo "🤖 AI Services:"
run_check "Ollama installed" "command -v ollama"
# Check if any Ollama models are available (skip if none installed)
OLLAMA_MODELS=$(ollama list 2>/dev/null | awk 'NR>1 && /^[a-zA-Z]/ {print $1; exit}' || echo "")
if [[ -n "$OLLAMA_MODELS" ]]; then
  run_check "Ollama model available" "ollama list | grep -qE '^[a-zA-Z]'"
  run_check "Ollama inference test" "echo 'test' | ollama run \"$OLLAMA_MODELS\" 'Say OK' 2>&1 | grep -qi ok"
else
  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
  echo -e "${YELLOW}⚠${NC} (no models installed - optional)"
  echo "    {\"name\": \"Ollama model available\", \"status\": \"skip\", \"reason\": \"no models installed\", \"timestamp\": \"$TIMESTAMP\"}," >> "$HEALTH_REPORT"
  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
  echo -e "${YELLOW}⚠${NC} (skipped - no models)"
  echo "    {\"name\": \"Ollama inference test\", \"status\": \"skip\", \"reason\": \"no models installed\", \"timestamp\": \"$TIMESTAMP\"}," >> "$HEALTH_REPORT"
fi

echo ""
echo "📊 Applications:"
run_check "Dashboard files exist" "test -f ~/02luka/g/apps/dashboard/index.html"
run_check "Dashboard data valid" "jq -e '.roadmap.overall_progress_pct' ~/02luka/g/apps/dashboard/dashboard_data.json"

echo ""
echo "🗂️ Data Integrity:"
run_check "Expense ledger exists" "test -f ~/02luka/g/apps/expense/ledger_2025.jsonl"
run_check "Expense ledger valid JSON" "head -1 ~/02luka/g/apps/expense/ledger_2025.jsonl | jq -e '.id'"
run_check "MLS lessons exist" "test -f ~/02luka/g/knowledge/mls_lessons.jsonl"
run_check "Roadmap exists" "test -f ~/02luka/g/roadmaps/ROADMAP_2025-11-04_autonomous_systems.md"

echo ""
echo "🔧 Tools:"
run_check "Categorization script" "test -x ~/02luka/tools/expense/ollama_categorize.zsh"
run_check "Agent status tool" "test -x ~/02luka/tools/agent_status.zsh"
run_check "Scanner tool" "test -x ~/02luka/tools/local_truth_scan.zsh"

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
echo "=== Summary ==="
echo "Total checks: $TOTAL_CHECKS"
echo -e "Passed: ${GREEN}$PASSED_CHECKS${NC}"
echo -e "Failed: ${RED}$FAILED_CHECKS${NC}"
echo "Success rate: $((PASSED_CHECKS * 100 / TOTAL_CHECKS))%"
echo ""
echo "Report saved: $HEALTH_REPORT"

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
