#!/usr/bin/env zsh
# Conflict Resolution Tool for Two-Way Sync
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

show_banner() {
  echo -e "${CYAN}"
  echo "════════════════════════════════════════════════════════════"
  echo "       GD Conflict Resolution Tool v1.0"
  echo "       Repository: 02luka"
  echo "════════════════════════════════════════════════════════════"
  echo -e "${NC}"
}

LOCAL="$HOME/02luka"
REMOTE="$HOME/gd/02luka_sync/current"
CONFLICT_DIR="$HOME/02luka/g/reports/sync_conflicts_$(date +%Y%m%d_%H%M%S)"

show_banner

echo -e "${BLUE}Scanning for conflicts...${NC}"
echo ""

# Find files with different timestamps
mkdir -p "$CONFLICT_DIR"
CONFLICTS_FOUND=0

DIRS=("g" "CLC" "manuals" "docs" "scripts" "agents" "bridge" "tools")

for d in "${DIRS[@]}"; do
  if [[ ! -d "$LOCAL/$d" ]] || [[ ! -d "$REMOTE/$d" ]]; then
    continue
  fi

  # Compare files
  while IFS= read -r local_file; do
    rel_path="${local_file#$LOCAL/$d/}"
    remote_file="$REMOTE/$d/$rel_path"

    if [[ -f "$remote_file" ]]; then
      local_time=$(stat -f%m "$local_file" 2>/dev/null || echo 0)
      remote_time=$(stat -f%m "$remote_file" 2>/dev/null || echo 0)

      if [[ $local_time -ne $remote_time ]]; then
        # Conflict detected
        CONFLICTS_FOUND=$((CONFLICTS_FOUND + 1))

        echo -e "${YELLOW}⚠️  Conflict #$CONFLICTS_FOUND:${NC} $d/$rel_path"
        echo "   Local:  $(date -r $local_time '+%Y-%m-%d %H:%M:%S')"
        echo "   Remote: $(date -r $remote_time '+%Y-%m-%d %H:%M:%S')"

        # Copy both versions for comparison
        mkdir -p "$CONFLICT_DIR/$d/$(dirname "$rel_path")"
        cp "$local_file" "$CONFLICT_DIR/$d/${rel_path}.LOCAL"
        cp "$remote_file" "$CONFLICT_DIR/$d/${rel_path}.REMOTE"

        # Auto-resolve: keep newer
        if [[ $local_time -gt $remote_time ]]; then
          echo -e "   ${GREEN}→ Keeping LOCAL (newer)${NC}"
          # Remote will be updated on next sync
        else
          echo -e "   ${CYAN}→ Keeping REMOTE (newer)${NC}"
          cp "$remote_file" "$local_file"
        fi
        echo ""
      fi
    fi
  done < <(find "$LOCAL/$d" -type f 2>/dev/null)
done

if [[ $CONFLICTS_FOUND -eq 0 ]]; then
  echo -e "${GREEN}✅ No conflicts found${NC}"
  rmdir "$CONFLICT_DIR" 2>/dev/null || true
else
  echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
  echo -e "${YELLOW}Conflicts resolved: $CONFLICTS_FOUND${NC}"
  echo -e "${YELLOW}Backup copies saved to:${NC}"
  echo "  $CONFLICT_DIR"
  echo ""
  echo "Both versions preserved with extensions:"
  echo "  *.LOCAL  - Version from local Mac"
  echo "  *.REMOTE - Version from Google Drive"
  echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
fi
