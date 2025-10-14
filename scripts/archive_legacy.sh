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
    say "✓ No legacy backups found"
    exit 0
  fi

  say "Found $LEGACY_COUNT legacy backup directories"

  # List legacy dirs with sizes
  say "Legacy backups (kept for rollback):"
  find "$BASE" -maxdepth 1 -name ".legacy_*" -type d -exec du -sh {} \; | sed 's/^/  /'

  say ""
  say "✅ Legacy backups preserved in-place"
  say "   Location: /02luka/.legacy_*"
  say "   Rollback: make centralize-rollback"
  say "   Cleanup: Managed by make tidy-retention (30+ days)"
  say ""
  say "⚠️  Note: tar archiving skipped (Google Drive Stream compatibility)"
}

main "$@"
