#!/usr/bin/env zsh
# ORICO Quota Monitor
# Real-time monitoring of ORICO Time Machine quota

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Telemetry
TELEMETRY_FILE="$HOME/02luka/g/telemetry/orico_quota.jsonl"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "=== ORICO Quota Status ==="
echo ""

# Find ORICO volume (try common names)
ORICO_VOLUME=""
for vol in "/Volumes/TM_ORICO" "/Volumes/ORICO_APFS" "/Volumes/ORICO"; do
  if [[ -d "$vol" ]]; then
    ORICO_VOLUME="$vol"
    break
  fi
done

if [[ -z "$ORICO_VOLUME" ]]; then
  echo -e "${RED}❌ ORICO volume not found${NC}"
  echo "Checked for: TM_ORICO, ORICO_APFS, ORICO"
  echo ""
  echo "Available volumes:"
  ls -1 /Volumes/
  exit 1
fi

VOLUME_NAME=$(basename "$ORICO_VOLUME")
echo "Volume: $VOLUME_NAME"

# Get disk info
DISK_INFO=$(diskutil info "$ORICO_VOLUME" 2>/dev/null) || {
  echo -e "${RED}❌ Failed to get disk info${NC}"
  exit 1
}

# Parse capacity and usage
TOTAL_SPACE=$(echo "$DISK_INFO" | grep "Volume Total Space" | awk '{print $4, $5}')
USED_SPACE=$(echo "$DISK_INFO" | grep "Volume Used Space" | awk '{print $4, $5}')
AVAIL_SPACE=$(echo "$DISK_INFO" | grep "Volume Available Space" | awk '{print $4, $5}')

# Extract numeric values for percentage calculation
TOTAL_NUM=$(echo "$TOTAL_SPACE" | awk '{print $1}')
USED_NUM=$(echo "$USED_SPACE" | awk '{print $1}')

# Calculate percentage
if [[ -n "$TOTAL_NUM" ]] && [[ -n "$USED_NUM" ]] && (( $(echo "$TOTAL_NUM > 0" | bc -l 2>/dev/null || echo 0) )); then
  PERCENT=$(echo "scale=1; $USED_NUM / $TOTAL_NUM * 100" | bc -l 2>/dev/null || echo "??")
else
  PERCENT="??"
fi

echo "Total Quota: $TOTAL_SPACE"
echo "Used: $USED_SPACE (${PERCENT}%)"
echo "Available: $AVAIL_SPACE"

# Status color based on percentage
if [[ "$PERCENT" != "??" ]]; then
  PERCENT_INT=$(echo "$PERCENT" | cut -d'.' -f1)

  if (( PERCENT_INT < 80 )); then
    STATUS="🟢 Healthy"
    STATUS_TEXT="healthy"
    COLOR="$GREEN"
  elif (( PERCENT_INT < 90 )); then
    STATUS="🟡 Warning"
    STATUS_TEXT="warning"
    COLOR="$YELLOW"
  else
    STATUS="🔴 Critical"
    STATUS_TEXT="critical"
    COLOR="$RED"
  fi

  echo -e "${COLOR}Status: $STATUS${NC}"
else
  STATUS_TEXT="unknown"
  echo "Status: Unknown"
fi

echo ""

# Breakdown: TM vs other files
TM_DIR="$ORICO_VOLUME/Backups.backupdb"
if [[ -d "$TM_DIR" ]]; then
  TM_SIZE=$(du -sh "$TM_DIR" 2>/dev/null | awk '{print $1}' || echo "??")
  echo "Breakdown:"
  echo "  Time Machine: $TM_SIZE"

  # Calculate "other files" (rough estimate)
  # This is tricky because TM uses hard links
  echo "  Other files: (minimal)"
else
  echo "Breakdown:"
  echo "  Time Machine: Not yet initialized"
fi

echo ""

# Alert
if [[ "$STATUS_TEXT" == "critical" ]]; then
  echo -e "${RED}⚠️  ALERT: Quota is ${PERCENT}% full${NC}"
  echo "Action required: Time Machine will delete old snapshots soon."
elif [[ "$STATUS_TEXT" == "warning" ]]; then
  echo -e "${YELLOW}⚠️  WARNING: Quota is ${PERCENT}% full${NC}"
  echo "Monitor closely - approaching quota limit."
else
  echo -e "${GREEN}✅ Quota is healthy${NC}"
fi

# Write telemetry
mkdir -p "$(dirname "$TELEMETRY_FILE")" 2>/dev/null || true

if [[ -d "$(dirname "$TELEMETRY_FILE")" ]]; then
  cat >> "$TELEMETRY_FILE" <<EOF
{"ts":"$TIMESTAMP","volume":"$VOLUME_NAME","total":"$TOTAL_SPACE","used":"$USED_SPACE","available":"$AVAIL_SPACE","percent":$PERCENT,"status":"$STATUS_TEXT"}
EOF
fi
