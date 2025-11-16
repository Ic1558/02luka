#!/bin/bash
# Master Conflict Resolution Script
# Provides multiple resolution strategies

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
  echo "╔════════════════════════════════════════════════════════════╗"
  echo "║        PR Conflict Resolution Tool v1.0                    ║"
  echo "║        Repository: 02luka                                  ║"
  echo "╚════════════════════════════════════════════════════════════╝"
  echo -e "${NC}"
}

show_status() {
  echo -e "${BLUE}Current Conflict Status:${NC}"
  echo "  • Total branches: 193"
  echo "  • Conflicting branches: 4"
  echo "  • Affected branches:"
  echo "    - codex/add-user-authentication-feature"
  echo "    - codex/add-user-authentication-feature-hhs830"
  echo "    - codex/add-user-authentication-feature-not1zo"
  echo "    - codex/add-user-authentication-feature-yiytty"
  echo ""
  echo -e "${YELLOW}Conflict Type:${NC} Architecture change (boss-api removed)"
  echo ""
}

show_menu() {
  echo -e "${GREEN}Resolution Options:${NC}"
  echo ""
  echo "  1) 🤖 Automatic Resolution (Recommended)"
  echo "     Automatically resolve all conflicts and attempt to push"
  echo ""
  echo "  2) 📦 Create Resolution Patches"
  echo "     Generate patch files for manual application"
  echo ""
  echo "  3) 📖 View Detailed Guide"
  echo "     Open comprehensive resolution documentation"
  echo ""
  echo "  4) 🔍 Re-check Conflicts"
  echo "     Run conflict detection again"
  echo ""
  echo "  5) 📊 View Conflict Analysis"
  echo "     Display detailed conflict report"
  echo ""
  echo "  6) ❌ Exit"
  echo ""
}

automatic_resolution() {
  echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║  Automatic Resolution                                      ║${NC}"
  echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
  echo ""

  if [ ! -f "resolve_pr_conflicts.sh" ]; then
    echo -e "${RED}Error: resolve_pr_conflicts.sh not found${NC}"
    return 1
  fi

  echo "This will:"
  echo "  1. Checkout each conflicting branch"
  echo "  2. Merge main and resolve conflicts"
  echo "  3. Commit the resolution"
  echo "  4. Attempt to push to remote"
  echo ""
  echo -e "${YELLOW}Note: Pushes may fail due to branch permissions${NC}"
  echo ""

  read -p "Proceed? (y/N): " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    ./resolve_pr_conflicts.sh
  else
    echo "Cancelled."
  fi
}

create_patches() {
  echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║  Create Resolution Patches                                 ║${NC}"
  echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
  echo ""

  if [ ! -f "create_resolution_patches.sh" ]; then
    echo -e "${RED}Error: create_resolution_patches.sh not found${NC}"
    return 1
  fi

  echo "This will create patch files that can be applied manually."
  echo ""

  read -p "Proceed? (y/N): " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    ./create_resolution_patches.sh
  else
    echo "Cancelled."
  fi
}

view_guide() {
  echo -e "${CYAN}Opening resolution guide...${NC}"
  echo ""

  if [ -f "CONFLICT_RESOLUTION_GUIDE.md" ]; then
    if command -v less &> /dev/null; then
      less CONFLICT_RESOLUTION_GUIDE.md
    else
      cat CONFLICT_RESOLUTION_GUIDE.md
    fi
  else
    echo -e "${RED}Error: CONFLICT_RESOLUTION_GUIDE.md not found${NC}"
  fi
}

recheck_conflicts() {
  echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║  Re-checking Conflicts                                     ║${NC}"
  echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
  echo ""

  if [ ! -f "check_pr_conflicts.sh" ]; then
    echo -e "${RED}Error: check_pr_conflicts.sh not found${NC}"
    return 1
  fi

  ./check_pr_conflicts.sh
}

view_analysis() {
  echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║  Conflict Analysis                                         ║${NC}"
  echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
  echo ""

  if [ -f "PR_CONFLICTS_SUMMARY.md" ]; then
    cat PR_CONFLICTS_SUMMARY.md
  else
    echo -e "${RED}Error: PR_CONFLICTS_SUMMARY.md not found${NC}"
  fi

  echo ""
  read -p "Press Enter to continue..."
}

# Main loop
main() {
  show_banner
  show_status

  while true; do
    show_menu
    read -p "Select option (1-6): " choice

    case $choice in
      1)
        automatic_resolution
        echo ""
        read -p "Press Enter to continue..."
        ;;
      2)
        create_patches
        echo ""
        read -p "Press Enter to continue..."
        ;;
      3)
        view_guide
        echo ""
        ;;
      4)
        recheck_conflicts
        echo ""
        read -p "Press Enter to continue..."
        ;;
      5)
        view_analysis
        ;;
      6)
        echo -e "${GREEN}Goodbye!${NC}"
        exit 0
        ;;
      *)
        echo -e "${RED}Invalid option. Please select 1-6.${NC}"
        sleep 2
        ;;
    esac

    clear
    show_banner
    show_status
  done
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
  main
fi
