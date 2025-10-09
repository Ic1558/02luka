#!/usr/bin/env bash
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

KEYWORD_MAP="${1:-config/project_keywords.tsv}"

if [ ! -f "$KEYWORD_MAP" ]; then
  echo "❌ Keyword map not found: $KEYWORD_MAP"
  exit 1
fi

echo "📋 Auto-mapping projects by keywords..."
echo "Using: $KEYWORD_MAP"
echo

updated=0
unchanged=0

# Process each report
for report in g/reports/*.md; do
  [ -f "$report" ] || continue

  # Skip if already has non-general project
  current_project=$(awk '/^---$/,/^---$/ {if($1=="project:") print $2}' "$report" | head -1)
  if [ -n "$current_project" ] && [ "$current_project" != "general" ]; then
    ((unchanged++))
    continue
  fi

  # Read report content (lowercase for matching)
  content=$(cat "$report" | tr '[:upper:]' '[:lower:]')

  # Try to match against keyword patterns
  matched_project=""
  while IFS=$'\t' read -r project pattern; do
    # Convert pipe-separated pattern to grep -E compatible
    if echo "$content" | grep -qiE "$pattern"; then
      matched_project="$project"
      break
    fi
  done < "$KEYWORD_MAP"

  # Update project if match found
  if [ -n "$matched_project" ]; then
    # Update the project: line in front-matter
    if grep -q "^project:" "$report"; then
      # Replace existing project line
      if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/^project:.*/project: $matched_project/" "$report"
      else
        sed -i "s/^project:.*/project: $matched_project/" "$report"
      fi
      echo "✅ $(basename "$report") → $matched_project"
      ((updated++))
    fi
  else
    ((unchanged++))
  fi
done

echo
echo "📊 Summary:"
echo "  Updated: $updated"
echo "  Unchanged: $unchanged"
echo
echo "Run 'make boss-refresh' to rebuild catalogs"
