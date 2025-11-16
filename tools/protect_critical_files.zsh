#!/usr/bin/env zsh
# Protect Critical Files - Prevents deletion of important 02LUKA files
# Checks for protected files before git operations

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROTECTED_FILE="$REPO_ROOT/.cursor/protected_files.txt"

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

if [ ! -f "$PROTECTED_FILE" ]; then
    echo "${YELLOW}Warning: Protected files list not found: $PROTECTED_FILE${NC}" >&2
    exit 0
fi

# Read protected files list
protected_files=()
while IFS= read -r line || [ -n "$line" ]; do
    # Skip comments and empty lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue
    
    # Remove leading/trailing whitespace
    line="${line##*( )}"
    line="${line%%*( )}"
    
    # Add to array if not empty
    [ -n "$line" ] && protected_files+=("$line")
done < "$PROTECTED_FILE"

if [ ${#protected_files[@]} -eq 0 ]; then
    echo "${YELLOW}Warning: No protected files found in list${NC}" >&2
    exit 0
fi

# Check git status for deleted files
deleted_files=()
while IFS= read -r line; do
    # Check for deleted files (D) or renamed files (R)
    if [[ "$line" =~ ^(D|R[0-9]+) ]]; then
        file_path=$(echo "$line" | awk '{print $2}')
        # Check if this file is in protected list
        for protected in "${protected_files[@]}"; do
            # Check exact match or if file path ends with protected path
            if [[ "$file_path" == "$protected" ]] || [[ "$file_path" == */"$protected" ]] || [[ "$file_path" == "$protected"/* ]]; then
                deleted_files+=("$file_path")
                break
            fi
        done
    fi
done < <(git status --porcelain 2>/dev/null || true)

# Also check staged deletions
while IFS= read -r line; do
    if [[ "$line" =~ ^(D|R[0-9]+) ]]; then
        file_path=$(echo "$line" | awk '{print $2}')
        for protected in "${protected_files[@]}"; do
            if [[ "$file_path" == "$protected" ]] || [[ "$file_path" == */"$protected" ]] || [[ "$file_path" == "$protected"/* ]]; then
                deleted_files+=("$file_path")
                break
            fi
        done
    fi
done < <(git diff --cached --name-status 2>/dev/null || true)

# Report findings
if [ ${#deleted_files[@]} -gt 0 ]; then
    echo "${RED}❌ ERROR: Attempted deletion of protected files!${NC}" >&2
    echo "" >&2
    echo "${RED}Protected files that would be deleted:${NC}" >&2
    for file in "${deleted_files[@]}"; do
        echo "  ${RED}✗${NC} $file" >&2
    done
    echo "" >&2
    echo "${YELLOW}These files are protected and should not be deleted.${NC}" >&2
    echo "${YELLOW}If you need to delete them, remove them from:${NC}" >&2
    echo "  $PROTECTED_FILE" >&2
    echo "" >&2
    exit 1
fi

echo "${GREEN}✅ No protected files deleted${NC}" >&2
exit 0
