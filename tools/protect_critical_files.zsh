#!/usr/bin/env zsh
# Protect Critical Files - Prevent Accidental Deletion
# Purpose: Check for deletion of protected files and warn/block

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROTECTED_FILE="$REPO_ROOT/.cursor/protected_files.txt"

if [ ! -f "$PROTECTED_FILE" ]; then
  echo "⚠️  Protected files list not found: $PROTECTED_FILE"
  exit 0
fi

# Get deleted files from git
DELETED_FILES=$(git diff --name-only --diff-filter=D HEAD 2>/dev/null || echo "")

if [ -z "$DELETED_FILES" ]; then
  exit 0
fi

# Check each deleted file against protected patterns
PROTECTED_PATTERNS=$(grep -v '^#' "$PROTECTED_FILE" | grep -v '^$' || echo "")

VIOLATIONS=()

while IFS= read -r deleted_file; do
  while IFS= read -r pattern; do
    if [[ -z "$pattern" ]]; then
      continue
    fi
    
    # Simple glob matching
    if [[ "$deleted_file" == $pattern ]] || [[ "$deleted_file" == */$pattern ]]; then
      VIOLATIONS+=("$deleted_file (matches: $pattern)")
      break
    fi
  done <<< "$PROTECTED_PATTERNS"
done <<< "$DELETED_FILES"

if [ ${#VIOLATIONS[@]} -gt 0 ]; then
  echo "❌ CRITICAL: Attempted deletion of protected files!"
  echo ""
  echo "Protected files detected in deletion:"
  for violation in "${VIOLATIONS[@]}"; do
    echo "  - $violation"
  done
  echo ""
  echo "These files are protected and should not be deleted."
  echo "If deletion is intentional, update .cursor/protected_files.txt first."
  echo ""
  exit 1
fi

exit 0
