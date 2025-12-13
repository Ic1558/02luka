#!/usr/bin/env zsh
# Time Machine Status Monitor
# Human-readable status for Time Machine backups

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=== Time Machine Status ==="
echo ""

# Check if Time Machine is enabled
TM_ENABLED=$(tmutil status | grep -o '"Running" = [01]' | cut -d' ' -f3 || echo "0")

if [[ "$TM_ENABLED" == "0" ]]; then
  echo -e "${RED}⚠️  Time Machine is DISABLED${NC}"
  echo "Enable it in: System Settings → General → Time Machine"
  exit 1
fi

# Get destination info
DEST_INFO=$(tmutil destinationinfo 2>/dev/null) || {
  echo -e "${RED}❌ No Time Machine destination configured${NC}"
  exit 1
}

# Parse destination name
DEST_NAME=$(echo "$DEST_INFO" | grep "Name" | head -1 | sed 's/.*: //')

# Parse destination ID
DEST_ID=$(echo "$DEST_INFO" | grep "ID" | head -1 | sed 's/.*: //')

# Parse mount point
MOUNT_POINT=$(echo "$DEST_INFO" | grep "Mount Point" | head -1 | sed 's/.*: //')

# Get backup status
TM_STATUS=$(tmutil status | grep "BackupPhase" | cut -d'"' -f4 || echo "Idle")

# Status icon and color
if [[ "$TM_STATUS" == "Idle" ]]; then
  STATUS_ICON="⏸"
  STATUS_COLOR="$YELLOW"
elif [[ "$TM_STATUS" == "BackingUp" ]]; then
  STATUS_ICON="⏳"
  STATUS_COLOR="$BLUE"
elif [[ "$TM_STATUS" == "ThinningPreBackup" ]] || [[ "$TM_STATUS" == "ThinningPostBackup" ]]; then
  STATUS_ICON="🗑️"
  STATUS_COLOR="$YELLOW"
else
  STATUS_ICON="✅"
  STATUS_COLOR="$GREEN"
fi

echo "Destination: $DEST_NAME"
echo -e "Status: ${STATUS_COLOR}${STATUS_ICON} $TM_STATUS${NC}"
echo ""

# Get last backup date
LAST_BACKUP=$(tmutil latestbackup 2>/dev/null || echo "None")

if [[ "$LAST_BACKUP" == "None" ]]; then
  echo -e "${RED}Last Backup: Never${NC}"
else
  # Extract timestamp from path
  BACKUP_TS=$(basename "$LAST_BACKUP")
  echo -e "${GREEN}Last Backup: $BACKUP_TS${NC}"
fi

echo "Next Backup: Automatic (hourly)"
echo ""

# Get quota info (if destination is APFS volume)
if [[ -n "$MOUNT_POINT" ]] && [[ -d "$MOUNT_POINT" ]]; then
  # Get disk identifier
  DISK_ID=$(diskutil info "$MOUNT_POINT" | grep "Device Identifier" | awk '{print $NF}')

  if [[ -n "$DISK_ID" ]]; then
    # Get APFS container info
    APFS_INFO=$(diskutil apfs list | grep -A 20 "$DISK_ID" 2>/dev/null || echo "")

    if [[ -n "$APFS_INFO" ]]; then
      # Extract capacity and used space
      CAPACITY=$(diskutil info "$MOUNT_POINT" | grep "Volume Total Space" | awk '{print $4, $5}')
      USED=$(diskutil info "$MOUNT_POINT" | grep "Volume Used Space" | awk '{print $4, $5}')
      AVAILABLE=$(diskutil info "$MOUNT_POINT" | grep "Volume Available Space" | awk '{print $4, $5}')

      # Calculate percentage (rough approximation)
      USED_NUM=$(echo "$USED" | awk '{print $1}')
      CAP_NUM=$(echo "$CAPACITY" | awk '{print $1}')

      if [[ -n "$USED_NUM" ]] && [[ -n "$CAP_NUM" ]] && (( $(echo "$CAP_NUM > 0" | bc -l 2>/dev/null || echo 0) )); then
        PERCENT=$(echo "scale=0; $USED_NUM / $CAP_NUM * 100" | bc -l 2>/dev/null || echo "??")

        # Color based on percentage
        if (( PERCENT < 80 )); then
          QUOTA_COLOR="$GREEN"
        elif (( PERCENT < 90 )); then
          QUOTA_COLOR="$YELLOW"
        else
          QUOTA_COLOR="$RED"
        fi

        echo -e "${QUOTA_COLOR}Quota: $USED / $CAPACITY (${PERCENT}% used)${NC}"
      else
        echo "Quota: $USED / $CAPACITY"
      fi
    fi
  fi
fi

# Get snapshot count
SNAPSHOTS=$(tmutil listbackups 2>/dev/null | wc -l | xargs)

if [[ "$SNAPSHOTS" == "0" ]]; then
  echo -e "${YELLOW}Snapshots: 0 (first backup pending)${NC}"
else
  echo "Snapshots: $SNAPSHOTS total"

  # Get oldest and newest
  OLDEST=$(tmutil listbackups 2>/dev/null | head -1 | xargs basename)
  NEWEST=$(tmutil listbackups 2>/dev/null | tail -1 | xargs basename)

  echo "  Oldest: $OLDEST"
  echo "  Newest: $NEWEST"
fi

echo ""
echo "✅ Time Machine is operational"
