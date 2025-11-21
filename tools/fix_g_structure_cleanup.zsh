#!/usr/bin/env zsh
#
# ACTUAL CLEANUP: Fix /g folder structure chaos
# Run after reviewing dry-run results
# Creates archive before moving anything
#

set -euo pipefail

SOT="$HOME/02luka"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ARCHIVE_DIR="$SOT/_archive/g_cleanup_$TIMESTAMP"

echo "=== ACTUAL CLEANUP: /g Structure Fix ==="
echo ""
echo "⚠️  This will archive and remove nested /g structures"
echo "📦 Archive location: $ARCHIVE_DIR"
echo ""
read "REPLY?Type 'YES' to continue: "

if [[ "$REPLY" != "YES" ]]; then
  echo "❌ Aborted by user"
  exit 1
fi

# Step 1: Create archive directory
echo ""
echo "📦 Creating archive directory..."
mkdir -p "$ARCHIVE_DIR"/{nested_g_g,tilde_path_g,metadata}

# Step 2: Save metadata
echo "📝 Saving metadata..."
{
  echo "Cleanup Date: $(date)"
  echo "User: $USER"
  echo "SOT: $SOT"
  echo ""
  echo "=== Structure Before Cleanup ==="
  du -sh "$SOT/g" "$SOT/g/g" "$SOT/_memory/g" "$SOT/~/02luka/g" 2>/dev/null || true
  echo ""
  echo "=== File Counts ==="
  echo "Nested /g/g files: $(find "$SOT/g/g" -type f 2>/dev/null | wc -l)"
  echo "Tilde path files: $(find "$SOT/~/02luka/g" -type f 2>/dev/null | wc -l)"
} > "$ARCHIVE_DIR/metadata/cleanup_log.txt"

# Step 3: Archive nested /g/g
if [[ -d "$SOT/g/g" ]]; then
  echo "📁 Archiving nested /g/g..."
  mv "$SOT/g/g" "$ARCHIVE_DIR/nested_g_g/"
  echo "  ✅ Moved to $ARCHIVE_DIR/nested_g_g/"
else
  echo "  ⏭️  No nested /g/g found"
fi

# Step 4: Archive weird tilde path
if [[ -d "$SOT/~/02luka/g" ]]; then
  echo "📁 Archiving tilde path ~/02luka/g..."
  mv "$SOT/~/02luka/g" "$ARCHIVE_DIR/tilde_path_g/"
  echo "  ✅ Moved to $ARCHIVE_DIR/tilde_path_g/"

  # Clean up empty parent directories
  rmdir "$SOT/~/02luka" 2>/dev/null && echo "  🗑️  Removed empty $SOT/~/02luka"
  rmdir "$SOT/~" 2>/dev/null && echo "  🗑️  Removed empty $SOT/~"
else
  echo "  ⏭️  No tilde path found"
fi

# Step 5: Verify main /g is intact
echo ""
echo "✅ Verifying main /g structure..."
if [[ -d "$SOT/g/.git" ]]; then
  echo "  ✅ Git repository intact"
else
  echo "  ⚠️  Warning: No .git found in $SOT/g"
fi

if [[ -d "$SOT/g/apps" ]] && [[ -d "$SOT/g/manuals" ]]; then
  echo "  ✅ Core directories present"
else
  echo "  ⚠️  Warning: Missing expected directories"
fi

# Step 6: Final status
echo ""
echo "=== Cleanup Complete ==="
echo ""
echo "✅ Archived:"
echo "  - Nested /g/g → $ARCHIVE_DIR/nested_g_g/"
echo "  - Tilde path → $ARCHIVE_DIR/tilde_path_g/"
echo ""
echo "✅ Preserved:"
echo "  - Main repo: $SOT/g"
echo "  - Memory backup: $SOT/_memory/g"
echo ""
echo "📦 Archive size: $(du -sh "$ARCHIVE_DIR" | awk '{print $1}')"
echo "🔍 Review archive: ls -lah $ARCHIVE_DIR"
echo ""
echo "⚠️  If everything works for 1 week, you can safely delete:"
echo "   rm -rf $ARCHIVE_DIR"
