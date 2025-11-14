#!/usr/bin/env zsh
set -euo pipefail

WO_ID="WO-251004-CLC-DRIVE-GIT-REPAIR"
date
echo "== ${WO_ID} : Start =="

# --- Paths ---
ACC_ROOT="$HOME/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com"
BASE="$ACC_ROOT/My Drive"
INNER="$BASE/02luka/02luka-repo"      # target repo (SOT)
OUTER="$BASE/02luka-repo"             # duplicate repo (if exists)
ARCH_HOME="$HOME/02luka/archive/local_drive_legacy"
ARCH_DUP="$HOME/02luka/archive/drive_duplicates_251004"
DEV="$HOME/dev"

mkdir -p "$ARCH_HOME" "$ARCH_DUP" "$DEV"

echo "== 1) Clean home leftovers =="
for d in "$HOME/My Drive" "$HOME/My Drive (ittipong.c@gmail.com) (1)" "$HOME/My"; do
  [ -e "$d" ] && { echo "Archive: $d"; mv -vn "$d" "$ARCH_HOME/"; } || true
done

echo "== 2) Ensure 02luka base exists =="
mkdir -p "$BASE/02luka"

echo "== 3) Move OUTER -> 02luka if INNER missing =="
if [ ! -d "$INNER" ] && [ -d "$OUTER" ]; then
  echo "Move $OUTER -> $BASE/02luka/"
  mv "$OUTER" "$BASE/02luka/"
fi

echo "== 4) Merge unique files OUTER -> INNER (if OUTER still exists) =="
if [ -d "$OUTER" ] && [ -d "$INNER" ]; then
  rsync -avu --ignore-existing "$OUTER/" "$INNER/"
  echo "Archive OUTER duplicate"
  mv "$OUTER" "$ARCH_DUP/02luka-repo_outer_$(date +%Y%m%d_%H%M%S)"
fi

echo "== 5) Repair .git in INNER =="
HAS_INNER_GIT="no"
[ -d "$INNER/.git" ] && HAS_INNER_GIT="yes"
if [ "$HAS_INNER_GIT" = "no" ]; then
  if [ -d "$OUTER/.git" ]; then
    echo "Found .git in OUTER -> moving to INNER"
    mv "$OUTER/.git" "$INNER/.git"
    HAS_INNER_GIT="yes"
  fi
fi

if [ "$HAS_INNER_GIT" = "no" ]; then
  if [ -n "${REMOTE_URL:-}" ]; then
    echo "Clone fresh from REMOTE_URL into temp, then overlay local-only files"
    TMPBASE="$BASE/02luka/.tmp_clone_${RANDOM}"
    mkdir -p "$TMPBASE"
    git -C "$TMPBASE" clone "$REMOTE_URL" repo
    rsync -a --ignore-existing "$INNER/" "$TMPBASE/repo/"
    rm -rf "$INNER"
    mv "$TMPBASE/repo" "$INNER"
    rm -rf "$TMPBASE"
    HAS_INNER_GIT="yes"
  else
    echo "No REMOTE_URL provided -> git init new repo (preserve files)"
    git -C "$INNER" init
    HAS_INNER_GIT="yes"
  fi
fi

echo "== 6) Finalize Git state =="
if [ "$HAS_INNER_GIT" = "yes" ]; then
  git -C "$INNER" add -A || true
  git -C "$INNER" commit -m "Normalize repo after Drive migration (${WO_ID})" || true
  git -C "$INNER" fetch origin || true
  git -C "$INNER" branch --set-upstream-to=origin/main main 2>/dev/null || \
  git -C "$INNER" branch -u origin/main 2>/dev/null || true
fi

echo "== 7) Symlink hub =="
ln -snf "$BASE/02luka" "$DEV/02luka"
ln -snf "$INNER"       "$DEV/02luka-repo"
ls -l "$DEV/02luka" "$DEV/02luka-repo"

echo "== 8) Spotlight off for Drive 02luka =="
mdutil -i off "$BASE/02luka" 2>/dev/null || true

echo "== 9) Offline pin (informational) =="
echo "Manual step (user/ops): set Available offline for:"
echo " - $BASE/02luka/02luka-repo"
echo " - $BASE/02luka/CLC"
echo " - $BASE/_reports"

echo "== 10) Health report =="
echo "-- Mounts --"; ls -ld "$ACC_ROOT" "$BASE" | sed 's/^/   /'
echo "-- Repo dir --"; ls -ld "$INNER" | sed 's/^/   /'
echo "-- Has .git? --"; [ -d "$INNER/.git" ] && echo "   YES" || echo "   NO"
echo "-- Git status --"; git -C "$INNER" status -s || echo "   N/A"
echo "-- Remotes --"; git -C "$INNER" remote -v || echo "   N/A"
echo "-- Archived (home leftovers) --"; ls -1 "$ARCH_HOME" 2>/dev/null | sed 's/^/   /' || true
echo "-- Archived (duplicates) --"; ls -1 "$ARCH_DUP" 2>/dev/null | sed 's/^/   /' || true

echo "== 11) Claude 401 note =="
echo "If Claude TUI shows 401 again, run /login in that session. Persisted caches depend on the app profile."

echo "== ${WO_ID} : Done =="
