#!/usr/bin/env zsh
# Phase15 Quick Health → MLS Integration
# Converts health check JSON to MLS ledger entry

set -euo pipefail

LUKA_HOME="${HOME}/02luka"
TS_ICT=$(TZ=Asia/Bangkok date '+%Y-%m-%dT%H:%M:%S%z')

# Run health check and get JSON
HEALTH_JSON=$(TZ=Asia/Bangkok "${LUKA_HOME}/tools/phase15_quick_health.zsh" --json 2>&1)

# Extract status
MCP_OK=$(echo "$HEALTH_JSON" | jq -r '.mcp_bridge.ok // false')
MLS_OK=$(echo "$HEALTH_JSON" | jq -r '.mls.ok // false')
OVERALL_OK=$(echo "$HEALTH_JSON" | jq -r '.ok // false')

# Determine context
if [[ "$MCP_OK" == "true" ]] && [[ "$MLS_OK" == "true" ]]; then
  CONTEXT="bridge"
  TYPE="health"
  SUMMARY="mcp=true, mls=true"
else
  CONTEXT="ci"
  TYPE="health"
  SUMMARY="mcp=${MCP_OK}, mls=${MLS_OK}"
fi

# Create MLS event JSON
MLS_EVENT=$(echo "$HEALTH_JSON" | jq --arg ts "$TS_ICT" --arg type "$TYPE" --arg context "$CONTEXT" --arg summary "$SUMMARY" '
  {
    ts: $ts,
    type: $type,
    title: "Phase15 Quick Health",
    summary: $summary,
    source: {
      producer: "quick_health",
      context: $context
    },
    payload: .
  }
')

# Save to temp file
TMP_FILE="/tmp/phase15_mls_event.json"
echo "$MLS_EVENT" > "$TMP_FILE"

# Add to MLS ledger using mls_add.zsh
if [[ -f "${LUKA_HOME}/tools/mls_add.zsh" ]]; then
  "${LUKA_HOME}/tools/mls_add.zsh" \
    --type "$TYPE" \
    --title "Phase15 Quick Health" \
    --summary "$SUMMARY" \
    --producer "quick_health" \
    --context "$CONTEXT" \
    --author "system" \
    --confidence 0.9
  echo "✅ Health check logged to MLS"
else
  echo "⚠️  mls_add.zsh not found - event saved to $TMP_FILE"
fi

# Return exit code based on health
if [[ "$OVERALL_OK" == "true" ]]; then
  exit 0
else
  exit 1
fi

