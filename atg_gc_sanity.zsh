#!/usr/bin/env zsh
set -euo pipefail

cd "$HOME/02luka"

# Use a local, writable inbox for testing (avoid symlink to 02luka_ws)
export ATG_INBOX="$PWD/tmp/ATG_test"
rm -rf "$ATG_INBOX"
mkdir -p "$ATG_INBOX"

echo "== Pre: list workfiles =="
find "$ATG_INBOX" -type f -name '.work_*.zsh.*' -maxdepth 3 -print 2>/dev/null || true

echo "== Create test orphan workfiles =="
mkdir -p "$ATG_INBOX/rejected/orphaned"
touch "$ATG_INBOX/.work_test_safe.zsh.$$" 
touch "$ATG_INBOX/rejected/orphaned/.work_test_poison.zsh.$$"

echo "== Run GC with TMP_DAYS=0 (should delete immediately) =="
TMP_DAYS=0 zsh tools/atg_gc.zsh

echo "== Post: list workfiles (should be empty or only truly new real ones) =="
find "$ATG_INBOX" -type f -name '.work_*.zsh.*' -maxdepth 3 -print 2>/dev/null || true

echo "== Retention sanity (create backdated files then GC) =="
mkdir -p "$ATG_INBOX/pending" "$ATG_INBOX/rejected" "$ATG_INBOX/archive"

# make files "old enough" to be pruned by your policy:
# pending >3d, rejected >7d, archive >30d
touch -t 202512150000 "$ATG_INBOX/pending/.pending_old.$$"        # 5 days old (from Dec 20)
touch -t 202512100000 "$ATG_INBOX/rejected/.rejected_old.$$"      # 10 days old
touch -t 202511150000 "$ATG_INBOX/archive/.archive_old.$$"        # 35 days old

TMP_DAYS=0 zsh tools/atg_gc.zsh

echo "== Check existence (should be gone) =="
for f in \
  "$ATG_INBOX/pending/.pending_old.$$" \
  "$ATG_INBOX/rejected/.rejected_old.$$" \
  "$ATG_INBOX/archive/.archive_old.$$" \
; do
  if [[ -e "$f" ]]; then
    echo "❌ STILL EXISTS: $f"
  else
    echo "✅ PRUNED: $f"
  fi
done
