#!/usr/bin/env zsh
# ═══════════════════════════════════════════════════════════════════════
# Shortcut A: Healthcheck + Copy JSON to Clipboard
# ═══════════════════════════════════════════════════════════════════════
# One-click: Run 4 healthcheck commands and copy JSON to clipboard
# ═══════════════════════════════════════════════════════════════════════

set -euo pipefail

LUKA_ROOT="${LUKA_SOT:-${HOME}/02luka}"

# Run healthcheck and capture JSON output
HEALTHCHECK_OUTPUT=$(zsh "${LUKA_ROOT}/tools/pr11_day0_healthcheck.zsh" 2>&1)

# Extract JSON portion (between the monitor status lines)
MONITOR_JSON=$(zsh "${LUKA_ROOT}/tools/monitor_v5_production.zsh" json 2>&1)

# Create combined output
COMBINED_OUTPUT=$(cat <<EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "gateway_processes": $(pgrep -fl "gateway_v3_router.py" | wc -l | tr -d ' '),
  "mary_processes": $(pgrep -fl "/agents/mary/mary.py" | wc -l | tr -d ' '),
  "monitor": $MONITOR_JSON,
  "errors_in_log": "$(tail -200 "${LUKA_ROOT}/g/telemetry/gateway_v3_router.log" 2>/dev/null | grep -iE 'error|traceback|exception' | wc -l | tr -d ' ')"
}
EOF
)

# Copy to clipboard (macOS)
echo "$COMBINED_OUTPUT" | pbcopy

# Also show in terminal
echo "✅ Healthcheck complete - JSON copied to clipboard"
echo ""
echo "$COMBINED_OUTPUT"
