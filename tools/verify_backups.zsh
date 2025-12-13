#!/usr/bin/env zsh
# Backup Integrity Verification
# Complete health check for Time Machine + rsync backup systems

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Exit codes
EXIT_HEALTHY=0
EXIT_WARNING=1
EXIT_CRITICAL=2

# Tracking
WARNINGS=0
CRITICAL=0

echo "=== Backup System Health Check ==="
echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# ============================================
# TIME MACHINE CHECKS
# ============================================
echo -e "${BLUE}[Time Machine]${NC}"

# Check 1: Destination mounted?
TM_DEST=$(tmutil destinationinfo 2>/dev/null | grep "Mount Point" | head -1 | sed 's/.*: //' || echo "")

if [[ -n "$TM_DEST" ]] && [[ -d "$TM_DEST" ]]; then
  TM_VOLUME=$(basename "$TM_DEST")
  echo -e "  ${GREEN}✅ Destination: $TM_VOLUME mounted${NC}"
else
  echo -e "  ${RED}❌ Destination: NOT MOUNTED${NC}"
  CRITICAL=$((CRITICAL + 1))
  TM_VOLUME="unknown"
fi

# Check 2: Last backup < 24 hours?
LAST_BACKUP=$(tmutil latestbackup 2>/dev/null || echo "")

if [[ -n "$LAST_BACKUP" ]] && [[ -d "$LAST_BACKUP" ]]; then
  # Get backup timestamp
  BACKUP_TS=$(basename "$LAST_BACKUP")
  BACKUP_DATE=$(echo "$BACKUP_TS" | cut -d'-' -f1-3)
  BACKUP_TIME=$(echo "$BACKUP_TS" | cut -d'-' -f4-6)

  # Convert to epoch (rough check - within last 86400 seconds)
  NOW=$(date +%s)
  BACKUP_EPOCH=$(date -j -f "%Y%m%d-%H%M%S" "$BACKUP_DATE-$BACKUP_TIME" +%s 2>/dev/null || echo "0")
  AGE=$((NOW - BACKUP_EPOCH))

  if (( AGE < 86400 )); then
    HOURS=$((AGE / 3600))
    echo -e "  ${GREEN}✅ Last backup: $HOURS hours ago${NC}"
  elif (( AGE < 172800 )); then
    DAYS=$((AGE / 86400))
    echo -e "  ${YELLOW}⚠️  Last backup: $DAYS day(s) ago${NC}"
    WARNINGS=$((WARNINGS + 1))
  else
    DAYS=$((AGE / 86400))
    echo -e "  ${RED}❌ Last backup: $DAYS day(s) ago (TOO OLD)${NC}"
    CRITICAL=$((CRITICAL + 1))
  fi
else
  echo -e "  ${RED}❌ Last backup: NEVER${NC}"
  CRITICAL=$((CRITICAL + 1))
fi

# Check 3: Quota not full?
if [[ -n "$TM_DEST" ]] && [[ -d "$TM_DEST" ]]; then
  USED=$(diskutil info "$TM_DEST" | grep "Volume Used Space" | awk '{print $4}')
  TOTAL=$(diskutil info "$TM_DEST" | grep "Volume Total Space" | awk '{print $4}')

  USED_NUM=$(echo "$USED" | sed 's/[^0-9.]//g')
  TOTAL_NUM=$(echo "$TOTAL" | sed 's/[^0-9.]//g')

  if [[ -n "$USED_NUM" ]] && [[ -n "$TOTAL_NUM" ]] && (( $(echo "$TOTAL_NUM > 0" | bc -l 2>/dev/null || echo 0) )); then
    PERCENT=$(echo "scale=0; $USED_NUM / $TOTAL_NUM * 100" | bc -l 2>/dev/null || echo "0")

    if (( PERCENT < 80 )); then
      echo -e "  ${GREEN}✅ Quota: ${PERCENT}% used (healthy)${NC}"
    elif (( PERCENT < 95 )); then
      echo -e "  ${YELLOW}⚠️  Quota: ${PERCENT}% used (warning)${NC}"
      WARNINGS=$((WARNINGS + 1))
    else
      echo -e "  ${RED}❌ Quota: ${PERCENT}% used (CRITICAL)${NC}"
      CRITICAL=$((CRITICAL + 1))
    fi
  else
    echo -e "  ${YELLOW}⚠️  Quota: Unable to determine${NC}"
  fi
else
  echo "  ⏭️  Quota: Skipped (destination not mounted)"
fi

# Check 4: Encryption working?
if [[ -n "$TM_DEST" ]] && [[ -d "$TM_DEST" ]]; then
  ENCRYPTED=$(diskutil info "$TM_DEST" | grep "FileVault" | grep "Yes" || echo "")

  if [[ -n "$ENCRYPTED" ]]; then
    echo -e "  ${GREEN}✅ Encryption: Active${NC}"
  else
    echo -e "  ${YELLOW}⚠️  Encryption: Not enabled${NC}"
    WARNINGS=$((WARNINGS + 1))
  fi
else
  echo "  ⏭️  Encryption: Skipped (destination not mounted)"
fi

echo ""

# ============================================
# RSYNC BACKUP CHECKS
# ============================================
echo -e "${BLUE}[rsync Backup]${NC}"

# Check 1: Destination mounted? (lukadata)
RSYNC_DEST=""
for vol in "/Volumes/lukadata" "/Volumes/Past Works"; do
  if [[ -d "$vol" ]]; then
    RSYNC_DEST="$vol"
    break
  fi
done

if [[ -n "$RSYNC_DEST" ]]; then
  RSYNC_VOLUME=$(basename "$RSYNC_DEST")
  echo -e "  ${GREEN}✅ Destination: $RSYNC_VOLUME mounted${NC}"
else
  echo -e "  ${RED}❌ Destination: NOT MOUNTED${NC}"
  CRITICAL=$((CRITICAL + 1))
  RSYNC_DEST="/Volumes/lukadata" # Default for checks
fi

# Check 2: Last backup < 24 hours?
BACKUP_DIR="$RSYNC_DEST/02luka_backup"
LATEST_LINK="$BACKUP_DIR/latest"

if [[ -L "$LATEST_LINK" ]] && [[ -d "$LATEST_LINK" ]]; then
  LATEST_BACKUP=$(readlink "$LATEST_LINK")
  BACKUP_NAME=$(basename "$LATEST_BACKUP")

  # Get modification time
  BACKUP_MTIME=$(stat -f %m "$LATEST_LINK" 2>/dev/null || echo "0")
  NOW=$(date +%s)
  AGE=$((NOW - BACKUP_MTIME))

  if (( AGE < 86400 )); then
    HOURS=$((AGE / 3600))
    echo -e "  ${GREEN}✅ Last backup: $HOURS hours ago${NC}"
  elif (( AGE < 172800 )); then
    DAYS=$((AGE / 86400))
    echo -e "  ${YELLOW}⚠️  Last backup: $DAYS day(s) ago${NC}"
    WARNINGS=$((WARNINGS + 1))
  else
    DAYS=$((AGE / 86400))
    echo -e "  ${RED}❌ Last backup: $DAYS day(s) ago (TOO OLD)${NC}"
    CRITICAL=$((CRITICAL + 1))
  fi

  echo -e "  ${GREEN}✅ Latest: $BACKUP_NAME/${NC}"
else
  echo -e "  ${RED}❌ Latest: NOT FOUND${NC}"
  CRITICAL=$((CRITICAL + 1))
fi

# Check 3: Rotation working? (7-day)
if [[ -d "$BACKUP_DIR" ]]; then
  BACKUP_COUNT=$(find "$BACKUP_DIR" -maxdepth 1 -type d -name "202[0-9][0-9][0-9][0-9][0-9]" | wc -l | xargs)

  if (( BACKUP_COUNT >= 3 )) && (( BACKUP_COUNT <= 10 )); then
    echo -e "  ${GREEN}✅ Rotation: $BACKUP_COUNT days kept${NC}"
  elif (( BACKUP_COUNT < 3 )); then
    echo -e "  ${YELLOW}⚠️  Rotation: Only $BACKUP_COUNT backup(s)${NC}"
    WARNINGS=$((WARNINGS + 1))
  else
    echo -e "  ${YELLOW}⚠️  Rotation: $BACKUP_COUNT backups (cleanup may be needed)${NC}"
    WARNINGS=$((WARNINGS + 1))
  fi
else
  echo -e "  ${RED}❌ Rotation: Backup directory not found${NC}"
  CRITICAL=$((CRITICAL + 1))
fi

echo ""

# ============================================
# OVERALL STATUS
# ============================================
echo -e "${BLUE}[Overall]${NC}"

if (( CRITICAL > 0 )); then
  echo -e "  ${RED}❌ CRITICAL: $CRITICAL issue(s) require immediate attention${NC}"
  echo ""
  echo "Next actions:"
  echo "  1. Check Time Machine settings"
  echo "  2. Ensure backup volumes are mounted"
  echo "  3. Run manual backup if needed"
  exit $EXIT_CRITICAL
elif (( WARNINGS > 0 )); then
  echo -e "  ${YELLOW}⚠️  WARNING: $WARNINGS issue(s) detected${NC}"
  echo ""
  echo "Next actions:"
  echo "  - Monitor backup frequency"
  echo "  - Consider enabling encryption if not enabled"
  echo "  - Run ~/02luka/tools/nas_backup.zsh if rsync is old"
  exit $EXIT_WARNING
else
  echo -e "  ${GREEN}✅ All systems operational${NC}"
  echo ""
  echo "Next actions: None required"
  exit $EXIT_HEALTHY
fi
