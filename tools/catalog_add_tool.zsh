#!/usr/bin/env zsh
# Catalog Add Tool - Add new tool/script to catalog.yaml
# Usage: zsh tools/catalog_add_tool.zsh <tool-name> [options]
# Example: zsh tools/catalog_add_tool.zsh git-restore-missing --entry "./tools/git_restore_missing_from_origin.zsh" --description "Restore files from origin/main"

set -euo pipefail

LUKA_BASE="${LUKA_BASE:-$HOME/02luka}"
CATALOG="$LUKA_BASE/tools/catalog.yaml"

# Check if catalog exists
if [[ ! -f "$CATALOG" ]]; then
  echo "Error: Catalog not found: $CATALOG" >&2
  exit 1
fi

# Parse arguments
TOOL_NAME="${1:-}"
if [[ -z "$TOOL_NAME" ]]; then
  echo "Usage: $0 <tool-name> [--entry <path>] [--description <desc>] [--usage <usage>] [--notes <notes>]" >&2
  exit 1
fi

shift

# Default values
ENTRY=""
DESCRIPTION=""
USAGE=""
NOTES=""
ENV=""
FLAGS=""

# Parse options
while [[ $# -gt 0 ]]; do
  case "$1" in
    --entry)
      ENTRY="$2"
      shift 2
      ;;
    --description)
      DESCRIPTION="$2"
      shift 2
      ;;
    --usage)
      USAGE="$2"
      shift 2
      ;;
    --notes)
      NOTES="$2"
      shift 2
      ;;
    --env)
      ENV="$2"
      shift 2
      ;;
    --flags)
      FLAGS="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Auto-detect entry if not provided
if [[ -z "$ENTRY" ]]; then
  # Try to find script in tools/
  if [[ -f "$LUKA_BASE/tools/${TOOL_NAME}.zsh" ]]; then
    ENTRY="./tools/${TOOL_NAME}.zsh"
  elif [[ -f "$LUKA_BASE/tools/${TOOL_NAME}.sh" ]]; then
    ENTRY="./tools/${TOOL_NAME}.sh"
  else
    echo "Warning: Could not auto-detect entry point. Please specify --entry" >&2
  fi
fi

# Generate YAML entry
YAML_ENTRY="  ${TOOL_NAME}:"

if [[ -n "$DESCRIPTION" ]]; then
  YAML_ENTRY="${YAML_ENTRY}
    description: \"${DESCRIPTION}\""
fi

if [[ -n "$ENTRY" ]]; then
  YAML_ENTRY="${YAML_ENTRY}
    entry: \"${ENTRY}\""
fi

if [[ -n "$USAGE" ]]; then
  YAML_ENTRY="${YAML_ENTRY}
    usage: \"${USAGE}\""
fi

if [[ -n "$ENV" ]]; then
  YAML_ENTRY="${YAML_ENTRY}
    env: \"${ENV}\""
fi

if [[ -n "$FLAGS" ]]; then
  YAML_ENTRY="${YAML_ENTRY}
    flags: \"${FLAGS}\""
fi

if [[ -n "$NOTES" ]]; then
  YAML_ENTRY="${YAML_ENTRY}
    notes: \"${NOTES}\""
fi

# Check if tool already exists
if grep -q "^  ${TOOL_NAME}:" "$CATALOG"; then
  echo "Error: Tool '${TOOL_NAME}' already exists in catalog" >&2
  echo "Current entry:" >&2
  grep -A 10 "^  ${TOOL_NAME}:" "$CATALOG" | head -15 >&2
  exit 1
fi

# Find insertion point (after last command, before aliases section)
INSERT_LINE=$(grep -n "^aliases:" "$CATALOG" | head -1 | cut -d: -f1)
if [[ -z "$INSERT_LINE" ]]; then
  # If no aliases section, append to end of commands
  INSERT_LINE=$(grep -n "^commands:" "$CATALOG" | head -1 | cut -d: -f1)
  # Find last command entry
  LAST_CMD_LINE=$(awk '/^commands:/{start=NR} /^[^ ]/{if(start && NR>start && $0 !~ /^  / && $0 !~ /^#/) {print NR; exit}}' "$CATALOG" || echo "")
  if [[ -n "$LAST_CMD_LINE" ]]; then
    INSERT_LINE=$((LAST_CMD_LINE - 1))
  fi
fi

# Create backup
cp "$CATALOG" "${CATALOG}.bak.$(date +%Y%m%d_%H%M%S)"

# Insert new entry
if [[ -n "$INSERT_LINE" ]]; then
  # Insert before aliases section
  sed -i '' "${INSERT_LINE}i\\
${YAML_ENTRY}
" "$CATALOG"
else
  # Append to end
  echo "" >> "$CATALOG"
  echo "$YAML_ENTRY" >> "$CATALOG"
fi

# Update catalog timestamp
CURRENT_DATE=$(date +%Y-%m-%d)
sed -i '' "s/^updated:.*/updated: \"${CURRENT_DATE}\"/" "$CATALOG"

echo "✓ Added '${TOOL_NAME}' to catalog"
echo "✓ Backup created: ${CATALOG}.bak.*"
echo ""
echo "Verify with: zsh tools/catalog_lookup.zsh ${TOOL_NAME}"
