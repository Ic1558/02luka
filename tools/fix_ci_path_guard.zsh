#!/usr/bin/env zsh
# Fix CI Path Guard - Move report files to correct subdirectories

set -euo pipefail

REPO_ROOT="${LUKA_SOT:-$HOME/02luka}"
cd "$REPO_ROOT"

echo "🔧 Fixing CI Path Guard - Moving Report Files"
echo "=============================================="
echo ""

# Create system directory if it doesn't exist
mkdir -p g/reports/system

# Find all .md files directly in g/reports/ (not in subdirectories)
FILES_TO_MOVE=$(find g/reports -maxdepth 1 -name "*.md" -type f 2>/dev/null || true)

if [[ -z "$FILES_TO_MOVE" ]]; then
  echo "✅ No files to move - all reports are in subdirectories"
  exit 0
fi

echo "📋 Files to move:"
echo "$FILES_TO_MOVE" | sed 's|^|  - |'
echo ""

# Move files
MOVED=0
for file in $FILES_TO_MOVE; do
  if [[ -f "$file" ]]; then
    filename=$(basename "$file")
    mv "$file" "g/reports/system/$filename"
    echo "  ✅ Moved: $filename → g/reports/system/"
    ((MOVED++))
  fi
done

echo ""
echo "✅ Moved $MOVED file(s) to g/reports/system/"
echo ""
echo "📋 Verification:"
REMAINING=$(find g/reports -maxdepth 1 -name "*.md" -type f 2>/dev/null || true)
if [[ -z "$REMAINING" ]]; then
  echo "  ✅ All report files are in subdirectories"
else
  echo "  ⚠️  Some files remain:"
  echo "$REMAINING" | sed 's|^|    - |'
fi
