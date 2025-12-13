#!/usr/bin/env zsh
# Time Machine Local Snapshot Cleanup
# Safely removes local APFS snapshots to free up space on Macintosh HD

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "=== Time Machine Local Snapshot Cleanup ==="
echo ""

# List local snapshots
LOCAL_SNAPS=$(tmutil listlocalsnapshots / 2>/dev/null | grep "com.apple.TimeMachine" | sed 's/com.apple.TimeMachine.//')

if [[ -z "$LOCAL_SNAPS" ]]; then
  echo -e "${GREEN}✅ No local snapshots found${NC}"
  echo "Your Macintosh HD has no local Time Machine snapshots."
  echo "This is normal if you've recently set up Time Machine."
  exit 0
fi

# Count snapshots
SNAP_COUNT=$(echo "$LOCAL_SNAPS" | wc -l | xargs)

echo -e "${YELLOW}Found $SNAP_COUNT local snapshot(s)${NC}"
echo ""
echo "Local snapshots are temporary copies stored on your main drive."
echo "They're safe to delete - your Time Machine backups on ORICO remain intact."
echo ""

# Calculate space used
SPACE_USED=$(df -h / | tail -1 | awk '{print $3}')
SPACE_AVAIL=$(df -h / | tail -1 | awk '{print $4}')

echo "Current Macintosh HD usage:"
echo "  Used: $SPACE_USED"
echo "  Available: $SPACE_AVAIL"
echo ""

# Show snapshots
echo "Snapshots to delete:"
echo "$LOCAL_SNAPS" | while read -r snap; do
  echo "  - $snap"
done
echo ""

# Ask for confirmation
echo -n "Delete ALL local snapshots? (y/N): "
read -r confirm

if [[ "$confirm" != "y" ]] && [[ "$confirm" != "Y" ]]; then
  echo "Cancelled."
  exit 0
fi

echo ""
echo "Deleting local snapshots..."

# Delete each snapshot
DELETED=0
echo "$LOCAL_SNAPS" | while read -r snap; do
  if tmutil deletelocalsnapshots "$snap" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Deleted: $snap"
    DELETED=$((DELETED + 1))
  else
    echo -e "${RED}✗${NC} Failed: $snap"
  fi
done

echo ""
echo -e "${GREEN}✅ Cleanup complete!${NC}"

# Show new space
SPACE_AVAIL_NEW=$(df -h / | tail -1 | awk '{print $4}')
echo "New available space: $SPACE_AVAIL_NEW"
echo ""
echo "Note: Freed space may not appear immediately."
echo "macOS will reclaim it within a few minutes."
