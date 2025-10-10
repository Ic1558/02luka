#!/usr/bin/env bash
set -euo pipefail

TS="$(date +%y%m%d_%H%M%S)"
BASE="$HOME/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka"
REPO="$BASE/02luka-repo"
TRASH="$REPO/.trash"
ARCHIVE="$TRASH/parent_legacy_$TS.tgz"

say(){ echo "[$(date +%H:%M:%S)] $*"; }

main() {
  say "== Archive Legacy Backups =="

  # Check if legacy dirs exist
  LEGACY_COUNT=$(find "$BASE" -maxdepth 1 -name ".legacy_*" -type d 2>/dev/null | wc -l | tr -d ' ')

  if [ "$LEGACY_COUNT" -eq 0 ]; then
    say "✓ No legacy backups to archive"
    exit 0
  fi

  say "Found $LEGACY_COUNT legacy backup directories"

  # Create trash dir
  mkdir -p "$TRASH"

  # Archive legacy dirs
  say "→ Creating archive: ${ARCHIVE##$REPO/}"
  tar -C "$BASE" -czf "$ARCHIVE" .legacy_* 2>/dev/null || {
    say "❌ tar failed"; exit 1;
  }

  # Verify archive
  ARCHIVE_SIZE=$(du -h "$ARCHIVE" | cut -f1)
  FILE_COUNT=$(tar -tzf "$ARCHIVE" | wc -l | tr -d ' ')
  say "✓ Archive created: $ARCHIVE_SIZE, $FILE_COUNT files"

  # Show sample contents
  say "Sample contents (first 10 files):"
  tar -tzf "$ARCHIVE" | head -10 | sed 's/^/  /'

  # Remove legacy dirs
  say "→ Removing legacy backup directories"
  rm -rf "$BASE"/.legacy_*

  say "✅ Legacy backups archived to ${ARCHIVE##$REPO/}"
  say "   Rollback: tar -C '$BASE' -xzf '$ARCHIVE'"
}

main "$@"
