#!/usr/bin/env zsh
# verify_monitoring_status.zsh — Daily health check for 02luka monitoring stack
# Reports failures to Telegram automatically
set -euo pipefail

: "${LUKA_HOME:?set LUKA_HOME}"

# Load Telegram credentials
if [[ -f "$LUKA_HOME/.env/alerts" ]]; then
  source "$LUKA_HOME/.env/alerts"
fi

TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS=0
FAIL=0
FAILURES=()

check() {
  local name="$1"
  local cmd="$2"
  printf "  %-40s " "$name"

  if eval "$cmd" >/dev/null 2>&1; then
    echo -e "${GREEN}✅${NC}"
    ((PASS++))
    return 0
  else
    echo -e "${RED}❌${NC}"
    ((FAIL++))
    FAILURES+=("$name")
    return 1
  fi
}

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║     02luka Monitoring Stack - Daily Health Verification        ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "$(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

echo "=== Core Services ==="
check "Prometheus (9090)" "curl -sf http://127.0.0.1:9090/-/healthy" || true
check "Alertmanager (9093)" "curl -sf http://127.0.0.1:9093/-/healthy" || true
check "Grafana (3000)" "curl -sf http://127.0.0.1:3000/api/health" || true
check "Boss API (4100)" "curl -sf http://127.0.0.1:4100/health" || true
echo ""

echo "=== Integration Tests ==="
check "Boss API target" "curl -s http://127.0.0.1:9090/api/v1/targets 2>&1 | grep -q '\"job\":\"bossapi\"'" || true
check "Alertmanager target" "curl -s http://127.0.0.1:9090/api/v1/targets 2>&1 | grep -q '\"job\":\"alertmanager\"'" || true
check "Prometheus → Alertmanager link" "curl -s http://127.0.0.1:9090/api/v1/alertmanagers 2>&1 | grep -q '127.0.0.1:9093'" || true
check "Telegram configured" "grep -q 'telegram_configs' $LUKA_HOME/data/alertmanager/alertmanager_runtime.yml" || true
echo ""

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                         SUMMARY                                ║"
echo "╠════════════════════════════════════════════════════════════════╣"
printf "║  ✅ PASSED:  %-3d / 8                                            ║\n" "$PASS"
printf "║  ❌ FAILED:  %-3d / 8                                            ║\n" "$FAIL"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Send Telegram notification on failures
send_telegram() {
  local message="$1"

  if [[ -z "$TELEGRAM_BOT_TOKEN" ]] || [[ -z "$TELEGRAM_CHAT_ID" ]]; then
    echo -e "${YELLOW}⚠️  Telegram credentials not configured, skipping notification${NC}"
    return 1
  fi

  curl -sf -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    -d "parse_mode=Markdown" \
    -d "text=${message}" >/dev/null 2>&1
}

if [ $FAIL -eq 0 ]; then
  echo -e "${GREEN}🎉 All checks passed - monitoring stack healthy!${NC}"
  exit 0
else
  echo -e "${RED}⚠️  $FAIL check(s) failed${NC}"
  echo ""
  echo "Failed checks:"
  for failure in "${FAILURES[@]}"; do
    echo "  - $failure"
  done

  # Build Telegram alert message
  MESSAGE="🚨 *02luka Monitoring Alert*

*Failed Checks:* $FAIL / 8

"

  for failure in "${FAILURES[@]}"; do
    MESSAGE="${MESSAGE}• ${failure}
"
  done

  MESSAGE="${MESSAGE}
*Time:* $(date '+%Y-%m-%d %H:%M:%S %Z')
*Host:* $(hostname)

Run manual check:
\`\`\`
cd $LUKA_HOME && tools/verify_monitoring_status.zsh
\`\`\`"

  echo ""
  echo "Sending Telegram notification..."
  if send_telegram "$MESSAGE"; then
    echo -e "${GREEN}✅ Telegram notification sent${NC}"
  else
    echo -e "${YELLOW}⚠️  Failed to send Telegram notification${NC}"
  fi

  exit 1
fi
