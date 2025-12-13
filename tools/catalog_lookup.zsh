#!/usr/bin/env zsh
# tools/catalog_lookup.zsh - Query interface for System Catalog
# Usage:
#   zsh catalog_lookup.zsh <command>         # Lookup specific command
#   zsh catalog_lookup.zsh --list            # List all commands
#   zsh catalog_lookup.zsh --search <term>   # Search by keyword
#   zsh catalog_lookup.zsh --json <command>  # Output as JSON

set -u

LUKA_BASE="${LUKA_BASE:-$HOME/02luka}"
CATALOG="$LUKA_BASE/tools/catalog.yaml"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Check if catalog exists
if [[ ! -f "$CATALOG" ]]; then
    echo "${RED}❌ Catalog not found: $CATALOG${NC}"
    exit 1
fi

# Check for yq (YAML parser)
if ! command -v yq &>/dev/null; then
    # Fallback to grep-based parsing
    USE_GREP=true
else
    USE_GREP=false
fi

show_help() {
    cat << 'EOF'
📚 System Catalog Lookup v1

USAGE:
    zsh catalog_lookup.zsh <command>         # Lookup command
    zsh catalog_lookup.zsh --list            # List all
    zsh catalog_lookup.zsh --search <term>   # Search
    zsh catalog_lookup.zsh --aliases         # Show aliases
    zsh catalog_lookup.zsh --help            # This help

EXAMPLES:
    zsh catalog_lookup.zsh save-now
    zsh catalog_lookup.zsh --search save
EOF
}

list_commands() {
    echo "${CYAN}📚 System Catalog Commands${NC}"
    echo "─────────────────────────────"
    
    if [[ "$USE_GREP" == "true" ]]; then
        grep -A5 "^  [a-z-]*:" "$CATALOG" | grep -E "^  [a-z-]*:|description:" | \
        while read line; do
            if [[ "$line" =~ ^[[:space:]]+([a-z-]+): ]]; then
                cmd="${match[1]}"
            elif [[ "$line" =~ description:[[:space:]]*\"(.*)\" ]]; then
                echo "  ${GREEN}$cmd${NC}: ${match[1]}"
            fi
        done
    else
        yq -r '.commands | keys[]' "$CATALOG" 2>/dev/null | while read cmd; do
            desc=$(yq -r ".commands.\"$cmd\".description // \"\"" "$CATALOG")
            echo "  ${GREEN}$cmd${NC}: $desc"
        done
    fi
}

list_aliases() {
    echo "${CYAN}📎 Aliases${NC}"
    echo "─────────────────────────────"
    
    if [[ "$USE_GREP" == "true" ]]; then
        sed -n '/^aliases:/,/^[a-z]/p' "$CATALOG" | grep -E "^  [a-z-]+:" | \
        while read line; do
            echo "  $line"
        done
    else
        yq -r '.aliases | to_entries[] | "  \(.key) → \(.value)"' "$CATALOG" 2>/dev/null
    fi
}

lookup_command() {
    local cmd="$1"
    
    echo "${CYAN}🔍 Lookup: $cmd${NC}"
    echo "─────────────────────────────"
    
    if [[ "$USE_GREP" == "true" ]]; then
        # Check if it's an alias first
        alias_target=$(grep -A1 "^  $cmd:" "$CATALOG" | grep -v "^  $cmd:" | head -1 | tr -d ' "')
        if [[ -n "$alias_target" ]] && grep -q "^aliases:" "$CATALOG"; then
            if sed -n '/^aliases:/,/^[a-z]/p' "$CATALOG" | grep -q "^  $cmd:"; then
                echo "${YELLOW}Alias:${NC} $cmd → $alias_target"
                cmd="$alias_target"
                echo ""
            fi
        fi
        
        # Lookup command
        if grep -q "^  $cmd:" "$CATALOG"; then
            echo "${GREEN}Command:${NC} $cmd"
            grep -A10 "^  $cmd:" "$CATALOG" | head -10 | while read line; do
                if [[ "$line" =~ ^[[:space:]]+([a-z_]+):[[:space:]]*(.*)$ ]]; then
                    key="${match[1]}"
                    val="${match[2]}"
                    val="${val//\"/}"
                    echo "  ${YELLOW}$key:${NC} $val"
                fi
            done
        else
            echo "${RED}❌ Command not found: $cmd${NC}"
            echo ""
            echo "Try: zsh catalog_lookup.zsh --list"
        fi
    else
        # Check aliases
        alias_target=$(yq -r ".aliases.\"$cmd\" // \"\"" "$CATALOG")
        if [[ -n "$alias_target" && "$alias_target" != "null" ]]; then
            echo "${YELLOW}Alias:${NC} $cmd → $alias_target"
            cmd="$alias_target"
            echo ""
        fi
        
        # Lookup command
        result=$(yq -r ".commands.\"$cmd\" // \"\"" "$CATALOG")
        if [[ -n "$result" && "$result" != "null" ]]; then
            echo "${GREEN}Command:${NC} $cmd"
            yq -r ".commands.\"$cmd\" | to_entries[] | \"  \(.key): \(.value)\"" "$CATALOG"
        else
            echo "${RED}❌ Command not found: $cmd${NC}"
        fi
    fi
}

search_catalog() {
    local term="$1"
    
    echo "${CYAN}🔎 Search: $term${NC}"
    echo "─────────────────────────────"
    
    grep -i "$term" "$CATALOG" | head -20 | while read line; do
        echo "  $line"
    done
}

# Parse arguments
case "${1:-}" in
    --help|-h)
        show_help
        ;;
    --list|-l)
        list_commands
        ;;
    --aliases|-a)
        list_aliases
        ;;
    --search|-s)
        if [[ -z "${2:-}" ]]; then
            echo "${RED}❌ Missing search term${NC}"
            exit 1
        fi
        search_catalog "$2"
        ;;
    "")
        echo "${RED}❌ Missing command${NC}"
        show_help
        exit 1
        ;;
    *)
        lookup_command "$1"
        ;;
esac
