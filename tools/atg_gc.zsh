#!/usr/bin/env zsh
set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$HOME/02luka}"
ATG_INBOX="${ATG_INBOX:-$REPO_ROOT/bridge/inbox/ATG}"

# Retention policy (tune if needed)
DAYS_PENDING="${ATG_GC_DAYS_PENDING:-3}"
DAYS_REJECTED="${ATG_GC_DAYS_REJECTED:-7}"
# TMP_DAYS remains as a legacy alias for ATG_GC_DAYS_TMP
DAYS_TMP="${ATG_GC_DAYS_TMP:-${TMP_DAYS:-2}}"
DAYS_LOG="${ATG_GC_DAYS_LOG:-14}"
ATG_GC_DAYS_ARCHIVE="${ATG_GC_DAYS_ARCHIVE:-30}"

mkdir -p "$ATG_INBOX/rejected" "$ATG_INBOX/pending" "$ATG_INBOX/processed" "$ATG_INBOX/archive"

# Helper: safe find delete (only inside ATG inbox)
_safe_prune() {
  local dir="$1"; shift
  local days="$1"; shift
  [[ -d "$dir" ]] || return 0
  if (( days <= 0 )); then
    # Delete immediately (no age threshold)
    find "$dir" -type f -print -delete 2>/dev/null || true
  else
    # Delete files older than N days
    find "$dir" -type f -mtime "+$days" -print -delete 2>/dev/null || true
  fi
}

echo "[atg_gc] repo=$REPO_ROOT inbox=$ATG_INBOX"
echo "[atg_gc] pending>${DAYS_PENDING}d rejected>${DAYS_REJECTED}d archive>${ATG_GC_DAYS_ARCHIVE:-30}d tmp>${DAYS_TMP}d logs>${DAYS_LOG}d"


# --- GC: orphan temp workfiles (can land in rejected/pending/etc) ---
# These are internal work artifacts and should never accumulate.
# We clean them across the whole ATG inbox tree, but ONLY within the inbox root.
if [[ -n "${ATG_INBOX:-}" ]] && [[ -d "$ATG_INBOX" ]]; then
  if (( DAYS_TMP <= 0 )); then
    find "$ATG_INBOX" -type f -name '.work_*.zsh.*' -print -delete 2>/dev/null || true
  else
    find "$ATG_INBOX" -type f -name '.work_*.zsh.*' -mtime "+$DAYS_TMP" -print -delete 2>/dev/null || true
  fi
  rmdir "$ATG_INBOX/tmp_orphans" 2>/dev/null || true
fi
# --- /GC: orphan temp workfiles ---


# 1) Temp work files left behind by daemon runs (common leak source)
#    Example: .work_test_safe.zsh.17468
_safe_prune "$ATG_INBOX" "$DAYS_TMP" \
  && find "$ATG_INBOX" -maxdepth 1 -type f -name ".work_*.zsh.*" -mtime "+$DAYS_TMP" -print -delete 2>/dev/null || true

# 2) Pending / Rejected folders
_safe_prune "$ATG_INBOX/pending" "$DAYS_PENDING"
_safe_prune "$ATG_INBOX/rejected" "$DAYS_REJECTED"

# 3) Daemon local log file if you ever add it (optional)
_safe_prune "$ATG_INBOX" "$DAYS_LOG" \
  && find "$ATG_INBOX" -maxdepth 1 -type f -name "daemon.log" -mtime "+$DAYS_LOG" -print -delete 2>/dev/null || true

# 4) Optional: archive processed scripts older than N days (keep evidence lightly)
#    Move (not delete) to archive, then prune archive after 90 days.
if [[ -d "$ATG_INBOX/processed" ]]; then
  find "$ATG_INBOX/processed" -type f -mtime "+$DAYS_PENDING" -print -exec mv -n {} "$ATG_INBOX/archive/" \; 2>/dev/null || true
  _safe_prune "$ATG_INBOX/archive" "$ATG_GC_DAYS_ARCHIVE"
fi

echo "[atg_gc] done"
