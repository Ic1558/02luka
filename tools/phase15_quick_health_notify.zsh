#!/usr/bin/env zsh
# Phase15 Quick Health → Notification
# Sends notification if health check fails

set -euo pipefail

LUKA_HOME="${HOME}/02luka"
TMP_FILE="/tmp/phase15_health_check.json"

# Run health check
TZ=Asia/Bangkok "${LUKA_HOME}/tools/phase15_quick_health.zsh" --json > "$TMP_FILE" 2>&1

# Check if OK
if ! jq -e '.ok == true' "$TMP_FILE" >/dev/null 2>&1; then
  TS_ICT=$(TZ=Asia/Bangkok date '+%Y-%m-%d %H:%M:%S %z')
  MSG="❌ Phase15 Quick Health failed at ${TS_ICT}"
  
  # Get details
  MCP_STATUS=$(jq -r '.mcp_bridge.ok // false' "$TMP_FILE")
  MLS_STATUS=$(jq -r '.mls.ok // false' "$TMP_FILE")
  
  MSG="${MSG}\n\nMCP Bridge: ${MCP_STATUS}\nMLS: ${MLS_STATUS}"
  
  # Try to send notification (if telegram_notify.zsh exists)
  if [[ -f "${LUKA_HOME}/tools/telegram_notify.zsh" ]]; then
    "${LUKA_HOME}/tools/telegram_notify.zsh" "$MSG" "$(cat "$TMP_FILE")" 2>/dev/null || true
  fi
  
  # Also print to console
  echo "$MSG" >&2
  echo "Health check details:" >&2
  jq '.' "$TMP_FILE" >&2
  
  exit 1
else
  echo "✅ Phase15 Quick Health: OK"
  exit 0
fi

