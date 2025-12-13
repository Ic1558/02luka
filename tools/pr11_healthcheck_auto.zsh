#!/usr/bin/env zsh
# ═══════════════════════════════════════════════════════════════════════
# PR-11 Auto Healthcheck (for LaunchAgent)
# ═══════════════════════════════════════════════════════════════════════
# Runs healthcheck automatically and saves results to JSON file
# Also copies to clipboard for manual review
# ═══════════════════════════════════════════════════════════════════════

set -euo pipefail

LUKA_ROOT="${LUKA_SOT:-${HOME}/02luka}"
RESULTS_DIR="${LUKA_ROOT}/g/reports/pr11_healthcheck"
TIMESTAMP=$(date +"%Y-%m-%dT%H:%M:%S")
JSON_FILE="${RESULTS_DIR}/${TIMESTAMP}.json"

# Create results directory
mkdir -p "$RESULTS_DIR"

# Run healthcheck and capture JSON output
MONITOR_JSON=$(zsh "${LUKA_ROOT}/tools/monitor_v5_production.zsh" json 2>&1)

# Get process counts
GATEWAY_COUNT=$(pgrep -fl "gateway_v3_router.py" | wc -l | tr -d ' ')
MARY_COUNT=$(pgrep -fl "/agents/mary/mary.py" | wc -l | tr -d ' ')

# Count errors in log
LOG_FILE="${LUKA_ROOT}/g/telemetry/gateway_v3_router.log"
ERROR_COUNT=0
if [[ -f "$LOG_FILE" ]]; then
    ERROR_COUNT=$(tail -200 "$LOG_FILE" | grep -iE 'error|traceback|exception' | wc -l | tr -d ' ')
fi

# Create combined output
COMBINED_OUTPUT=$(cat <<EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "local_time": "$(date +"%Y-%m-%d %H:%M:%S")",
  "gateway_processes": $GATEWAY_COUNT,
  "mary_processes": $MARY_COUNT,
  "monitor": $MONITOR_JSON,
  "errors_in_log": $ERROR_COUNT,
  "status": "$(if [[ "$GATEWAY_COUNT" == "1" ]] && [[ "$MARY_COUNT" == "1" ]]; then echo "healthy"; else echo "warning"; fi)"
}
EOF
)

# Save to JSON file
echo "$COMBINED_OUTPUT" > "$JSON_FILE"

# Copy to clipboard (macOS)
echo "$COMBINED_OUTPUT" | pbcopy

# Log summary
echo "[$(date +"%Y-%m-%d %H:%M:%S")] PR-11 Healthcheck: Gateway=$GATEWAY_COUNT, Mary=$MARY_COUNT, Errors=$ERROR_COUNT, Status=$(echo "$COMBINED_OUTPUT" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)"
echo "[$(date +"%Y-%m-%d %H:%M:%S")] Results saved to: $JSON_FILE"

# Keep only last 100 results (cleanup old files)
find "$RESULTS_DIR" -name "*.json" -type f | sort -r | tail -n +101 | xargs rm -f 2>/dev/null || true

exit 0
