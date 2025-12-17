#!/usr/bin/env zsh
# catalog_auto_update.zsh — Auto-Update Catalog from Tools Directory
#
# Purpose: Scan tools/ directory and suggest catalog updates
# Frequency: On-demand or scheduled (not automatic by default)
#
# Usage: 
#   zsh tools/catalog_auto_update.zsh --scan    # Scan and suggest updates
#   zsh tools/catalog_auto_update.zsh --update # Auto-update (with confirmation)

set -uo pipefail

LUKA_BASE="${LUKA_BASE:-$HOME/02luka}"
CATALOG="$LUKA_BASE/tools/catalog.yaml"
TOOLS_DIR="$LUKA_BASE/tools"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

scan_tools() {
    echo "${CYAN}🔍 Scanning tools/ directory...${NC}"
    echo ""
    
    # Find all executable scripts
    tools_found=$(find "$TOOLS_DIR" -maxdepth 1 -type f \( -name "*.zsh" -o -name "*.sh" \) -perm +111 2>/dev/null | sort)
    
    echo "${CYAN}Found tools:${NC}"
    echo "$tools_found" | while read tool; do
        tool_name=$(basename "$tool" .zsh | sed 's/\.sh$//')
        if ! grep -q "^  $tool_name:" "$CATALOG" 2>/dev/null; then
            echo "  ${YELLOW}⚠️  Not in catalog:${NC} $tool_name ($(basename "$tool"))"
        else
            echo "  ${GREEN}✅ In catalog:${NC} $tool_name"
        fi
    done
}

update_catalog() {
    echo "${CYAN}📝 Updating catalog...${NC}"
    echo ""
    echo "${YELLOW}⚠️  Auto-update not implemented yet${NC}"
    echo "   Catalog is curated manually for now"
    echo "   Use --scan to see suggestions, then update catalog.yaml manually"
}

case "${1:-}" in
    --scan)
        scan_tools
        ;;
    --update)
        update_catalog
        ;;
    --help|-h)
        cat << 'EOF'
Catalog Auto-Update Tool

USAGE:
    zsh tools/catalog_auto_update.zsh --scan    # Scan and suggest updates
    zsh tools/catalog_auto_update.zsh --update  # Auto-update (not implemented)

NOTE:
    Catalog is curated manually (not auto-scanned) to ensure quality.
    Use --scan to see tools not in catalog, then add them manually.

    For scheduled updates, create a LaunchAgent that runs:
    zsh tools/catalog_auto_update.zsh --scan > logs/catalog_scan.log
EOF
        ;;
    *)
        echo "${RED}❌ Missing argument${NC}"
        echo "Usage: zsh tools/catalog_auto_update.zsh [--scan|--update|--help]"
        exit 1
        ;;
esac

