#!/usr/bin/env zsh
set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$HOME/02luka}"
ATG_INBOX="$REPO_ROOT/bridge/inbox/ATG"

# Retention policy (tune if needed)
DAYS_PENDING="${ATG_GC_DAYS_PENDING:-7}"
DAYS_REJECTED="${ATG_GC_DAYS_REJECTED:-14}"
DAYS_TMP="${ATG_GC_DAYS_TMP:-2}"
DAYS_LOG="${ATG_GC_DAYS_LOG:-14}"

mkdir -p "$ATG_INBOX/rejected" "$ATG_INBOX/pending" "$ATG_INBOX/processed" "$ATG_INBOX/archive"

# Helper: safe find delete (only inside ATG inbox)
_safe_prune() {
  local dir="$1"; shift
  local days="$1"; shift
  [[ -d "$dir" ]] || return 0
  # Delete files older than N days
  find "$dir" -type f -mtime "+$days" -print -delete 2>/dev/null || true
}

echo "[atg_gc] repo=$REPO_ROOT"
echo "[atg_gc] pending>${DAYS_PENDING}d rejected>${DAYS_REJECTED}d archive>${ATG_GC_DAYS_ARCHIVE:-90}d tmp>${DAYS_TMP}d logs>${DAYS_LOG}d"

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
  _safe_prune "$ATG_INBOX/archive" "${ATG_GC_DAYS_ARCHIVE:-90}"
fi

echo "[atg_gc] done"
