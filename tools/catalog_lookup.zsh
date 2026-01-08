#!/usr/bin/env zsh
# tools/catalog_lookup.zsh
# Purpose: Extract canonical tool path from CATALOG.md based on alias/keyword
set -u

CATALOG_FILE="${REPO_ROOT:-$HOME/02luka}/tools/CATALOG.md"
QUERY="$1"

if [[ ! -f "$CATALOG_FILE" ]]; then
  echo "Error: Catalog not found at $CATALOG_FILE" >&2
  exit 1
fi

# Map common aliases to exact tool names or paths if necessary, 
# or simpler: grep the table row containing the query and extract the code block.

# 1. Try exact alias mapping (preferred for stability)
case "$QUERY" in
  "save") PATTERN="Save Session" ;;
  "bridge-check"|"bridge_selfcheck") PATTERN="Bridge Self-Check" ;;
  "core-history"|"history") PATTERN="Build Core History" ;;
  "verify-core") PATTERN="Verify Core State" ;;
  *) PATTERN="$QUERY" ;;
esac

# 2. Search catalog
# Look for line with PATTERN, then extract `tools/xxx` from inside backticks
# Markdown Table Format: | **Name** | `path` | ...
# We match the line with PATTERN, then look for backticked path.
MATCH_LINE=$(grep -i "$PATTERN" "$CATALOG_FILE" | head -n 1)

if [[ -z "$MATCH_LINE" ]]; then
  # Fallback: try searching for the script filename directly in the catalog
  MATCH_LINE=$(grep -F "$QUERY" "$CATALOG_FILE" | head -n 1)
fi

if [[ -z "$MATCH_LINE" ]]; then
  exit 1 # Not found
fi

# Extract text between ` ` (backticks) assuming the first code block is the path
PATH_MATCH=$(echo "$MATCH_LINE" | grep -o '`[^`]*`' | head -n 1 | tr -d '`')

# Validate
if [[ -n "$PATH_MATCH" && -f "$HOME/02luka/$PATH_MATCH" ]]; then
  echo "$PATH_MATCH"
else
  # Try pre-pending tools/ if missing
  if [[ -f "$HOME/02luka/tools/$PATH_MATCH" ]]; then
     echo "tools/$PATH_MATCH"
  else
     exit 2 # Found in catalog but file missing
  fi
fi
