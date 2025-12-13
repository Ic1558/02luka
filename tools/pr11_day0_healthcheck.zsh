#!/usr/bin/env zsh
# ═══════════════════════════════════════════════════════════════════════
# PR-11 Day 0 Healthcheck
# ═══════════════════════════════════════════════════════════════════════
# Runs 4 critical checks for Day 0 stability monitoring:
# 1. Gateway v3 Router process count
# 2. Mary agent process count
# 3. Monitor v5 production status (JSON)
# 4. Error scan in telemetry log
# ═══════════════════════════════════════════════════════════════════════

set -euo pipefail

LUKA_ROOT="${LUKA_SOT:-${HOME}/02luka}"
LOG_FILE="${LUKA_ROOT}/g/telemetry/gateway_v3_router.log"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

echo "═══════════════════════════════════════════════════════════════"
echo "PR-11 Day 0 Healthcheck - ${TIMESTAMP}"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# 1. Gateway v3 Router process count
GATEWAY_COUNT=$(pgrep -fl "gateway_v3_router.py" | wc -l | tr -d ' ')
echo "1️⃣  Gateway v3 Router processes: ${GATEWAY_COUNT}"
if [[ "$GATEWAY_COUNT" != "1" ]]; then
    echo "   ⚠️  WARNING: Expected 1, found ${GATEWAY_COUNT}"
fi
echo ""

# 2. Mary agent process count
MARY_COUNT=$(pgrep -fl "/agents/mary/mary.py" | wc -l | tr -d ' ')
echo "2️⃣  Mary agent processes: ${MARY_COUNT}"
if [[ "$MARY_COUNT" != "1" ]]; then
    echo "   ⚠️  WARNING: Expected 1, found ${MARY_COUNT}"
fi
echo ""

# 3. Monitor v5 production status (JSON)
echo "3️⃣  Monitor v5 Production Status:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
MONITOR_JSON=$(zsh "${LUKA_ROOT}/tools/monitor_v5_production.zsh" json 2>&1)
echo "$MONITOR_JSON"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 4. Error scan in telemetry log
echo "4️⃣  Error Scan (last 200 lines):"
if [[ -f "$LOG_FILE" ]]; then
    ERROR_OUTPUT=$(tail -200 "$LOG_FILE" | grep -iE 'error|traceback|exception' || echo "✅ OK: no errors")
    echo "$ERROR_OUTPUT"
else
    echo "   ⚠️  WARNING: Log file not found: $LOG_FILE"
fi
echo ""

# Summary
echo "═══════════════════════════════════════════════════════════════"
if [[ "$GATEWAY_COUNT" == "1" ]] && [[ "$MARY_COUNT" == "1" ]] && [[ -f "$LOG_FILE" ]]; then
    echo "✅ All checks passed"
    exit 0
else
    echo "⚠️  Some checks need attention"
    exit 1
fi
