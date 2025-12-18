#!/usr/bin/env zsh
# Catalog Auto Scan - Scan tools/ directory and suggest missing entries
# Usage: zsh tools/catalog_auto_scan.zsh [--dry-run] [--add-missing]

set -euo pipefail

LUKA_BASE="${LUKA_BASE:-$HOME/02luka}"
TOOLS_DIR="$LUKA_BASE/tools"
CATALOG="$LUKA_BASE/tools/catalog.yaml"

DRY_RUN=false
ADD_MISSING=false

# Parse options
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --add-missing)
      ADD_MISSING=true
      shift
      ;;
    *)
      echo "Usage: $0 [--dry-run] [--add-missing]" >&2
      exit 1
      ;;
  esac
done

echo "==> Scanning tools/ directory for scripts..."

# Find all executable scripts (macOS compatible)
SCRIPTS=($(find "$TOOLS_DIR" -maxdepth 1 -type f \( -name "*.zsh" -o -name "*.sh" \) -perm +111 2>/dev/null | sort))

echo "Found ${#SCRIPTS[@]} executable scripts"
echo

# Extract tool names from catalog
CATALOGED_TOOLS=($(grep -E "^  [a-z-]+:" "$CATALOG" | sed 's/^  //; s/:$//' | sort))

MISSING=()

for script in "${SCRIPTS[@]}"; do
  script_name=$(basename "$script" .zsh | sed 's/\.sh$//')
  
  # Skip if already in catalog
  if printf '%s\n' "${CATALOGED_TOOLS[@]}" | grep -q "^${script_name}$"; then
    continue
  fi
  
  # Skip backup files
  if [[ "$script_name" =~ \.(bak|old|backup) ]]; then
    continue
  fi
  
  MISSING+=("$script_name:$script")
done

if [[ ${#MISSING[@]} -eq 0 ]]; then
  echo "✓ All scripts are in catalog"
  exit 0
fi

echo "==> Found ${#MISSING[@]} scripts not in catalog:"
echo

for item in "${MISSING[@]}"; do
  tool_name="${item%%:*}"
  script_path="${item#*:}"
  echo "  - $tool_name ($script_path)"
done

echo

if [[ "$DRY_RUN" == "true" ]]; then
  echo "==> Dry run mode - no changes made"
  echo "==> To add missing tools, run: $0 --add-missing"
  exit 0
fi

if [[ "$ADD_MISSING" == "true" ]]; then
  echo "==> Adding missing tools to catalog..."
  echo
  
  for item in "${MISSING[@]}"; do
    tool_name="${item%%:*}"
    script_path="${item#*:}"
    rel_path="./tools/$(basename "$script_path")"
    
    # Try to extract description from script
    desc=$(grep -E "^#.*description|^#.*Description|^#.*Purpose" "$script_path" | head -1 | sed 's/^# *//; s/.*[Dd]escription: *//; s/.*[Pp]urpose: *//' || echo "Tool: $tool_name")
    
    echo "Adding: $tool_name"
    zsh "$LUKA_BASE/tools/catalog_add_tool.zsh" "$tool_name" \
      --entry "$rel_path" \
      --description "$desc" \
      --notes "Auto-added by catalog_auto_scan.zsh"
  done
  
  echo
  echo "✓ Done. Verify with: zsh tools/catalog_lookup.zsh <tool-name>"
else
  echo "==> To add missing tools, run: $0 --add-missing"
  echo "==> Or add manually: zsh tools/catalog_add_tool.zsh <tool-name> [options]"
fi
