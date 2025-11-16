#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LANE="${SAVE_SH_LANE:-UNSPECIFIED}"
START_TS="$(date -Iseconds)"
START_EPOCH="$(date +%s)"
LOG_DIR="${REPO_ROOT}/logs/save_sh"
mkdir -p "$LOG_DIR"
SAFE_TS="${START_TS//[:]/-}"
LOG_FILE="${LOG_DIR}/save_${SAFE_TS}.log"
LOG_REL="${LOG_FILE#${REPO_ROOT}/}"
MLS_STATUS="skipped"
MLS_REQUIRED=0

# Optional hooks (defaults keep legacy behavior)
SAVE_SH_AUTOCOMMIT="${SAVE_SH_AUTOCOMMIT:-0}"
SAVE_SH_MLS_LOG="${SAVE_SH_MLS_LOG:-0}"
SAVE_SH_TARGET_FILE="${SAVE_SH_TARGET_FILE:-}"

finish() {
  local exit_code=$?
  local end_ts
  local duration
  end_ts="$(date -Iseconds)"
  duration=$(( $(date +%s) - START_EPOCH ))
  if [[ $exit_code -eq 0 ]]; then
    echo "=== save.sh:end status=success code=${exit_code} lane=${LANE} duration=${duration}s ts=${end_ts} ==="
  else
    echo "=== save.sh:end status=failure code=${exit_code} lane=${LANE} duration=${duration}s ts=${end_ts} ===" >&2
  fi
}
trap finish EXIT

echo "=== save.sh:start lane=${LANE} ts=${START_TS} ==="

declare -a git_cmd=(git -C "$REPO_ROOT")
if ! "${git_cmd[@]}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "save.sh must be executed inside a git repository" >&2
  exit 2
fi

BRANCH=$("${git_cmd[@]}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "detached")
COMMIT=$("${git_cmd[@]}" rev-parse --short HEAD 2>/dev/null || echo "unknown")

STATUS_OUTPUT=$("${git_cmd[@]}" status --short || true)
if [[ -z "$STATUS_OUTPUT" ]]; then
  STATUS_OUTPUT="(clean)"
fi

DIFFSTAT_OUTPUT=$("${git_cmd[@]}" diff --stat || true)
if [[ -z "$DIFFSTAT_OUTPUT" ]]; then
  DIFFSTAT_OUTPUT="(no diff)"
fi

cat > "$LOG_FILE" <<LOG
# save.sh workspace snapshot
timestamp: $START_TS
lane: $LANE
repo: $REPO_ROOT
branch: $BRANCH
commit: $COMMIT

## git status --short
$STATUS_OUTPUT

## git diff --stat
$DIFFSTAT_OUTPUT
LOG

cat <<INFO
Workspace snapshot captured for lane: $LANE
Repository : $REPO_ROOT
Branch     : $BRANCH ($COMMIT)
Work tree  : $( [[ "$STATUS_OUTPUT" == "(clean)" ]] && echo "clean" || echo "dirty" )
Snapshot   : $LOG_REL
INFO

echo "NOTE: save.sh never runs 'git commit' or 'git push'. Finish your review and commit manually." 

echo "git status --short"
printf '%s\n' "$STATUS_OUTPUT"

echo "git diff --stat"
printf '%s\n' "$DIFFSTAT_OUTPUT"

if [[ "${LUKA_MLS_AUTO_RECORD:-0}" == "1" ]]; then
  MLS_REQUIRED=1
  MLS_SCRIPT="$REPO_ROOT/tools/mls_auto_record.zsh"
  MLS_HOME_OVERRIDE="${LUKA_MLS_HOME_OVERRIDE:-$(cd "${REPO_ROOT}/.." && pwd)}"
  if [[ -x "$MLS_SCRIPT" ]]; then
    SUMMARY="Workspace snapshot stored in $LOG_REL for branch $BRANCH ($COMMIT) on lane $LANE."
    if HOME="$MLS_HOME_OVERRIDE" "$MLS_SCRIPT" lesson "save.sh full-cycle ($LANE)" "$SUMMARY" "save.sh,workspace,lane:$LANE" >/dev/null 2>&1; then
      MLS_STATUS="recorded"
      echo "::save.sh:mls status=recorded lane=${LANE}::"
    else
      MLS_STATUS="failed"
      echo "::save.sh:mls status=failed lane=${LANE}::" >&2
    fi
  else
    MLS_STATUS="missing_hook"
    echo "::save.sh:mls status=missing_hook lane=${LANE}::" >&2
  fi
else
  echo "::save.sh:mls status=disabled lane=${LANE}::"
fi

if [[ $MLS_REQUIRED -eq 1 && "$MLS_STATUS" != "recorded" ]]; then
  echo "save.sh: MLS auto-record requested but status=${MLS_STATUS}" >&2
  exit 7
fi

# Optional auto-commit hook (opt-in via SAVE_SH_AUTOCOMMIT=1)
if [[ "$SAVE_SH_AUTOCOMMIT" == "1" ]]; then
  if [[ -n "$SAVE_SH_TARGET_FILE" ]]; then
    (
      cd "$REPO_ROOT" || exit 0
      git add -- "$SAVE_SH_TARGET_FILE" 2>/dev/null || true
      if git -C "$REPO_ROOT" diff --cached --quiet 2>/dev/null; then
        echo "[save.sh] no staged changes, skipping auto-commit"
      else
        git -C "$REPO_ROOT" commit -m "chore(save): auto-save via save.sh (${SAVE_SH_TARGET_FILE})" \
          >/dev/null 2>&1 || true
        echo "[save.sh] auto-commit attempted for ${SAVE_SH_TARGET_FILE}"
      fi
    )
  else
    echo "[save.sh] SAVE_SH_AUTOCOMMIT=1 set, but SAVE_SH_TARGET_FILE is empty - skipping commit"
  fi
fi

# Optional MLS logging hook (opt-in via SAVE_SH_MLS_LOG=1)
if [[ "$SAVE_SH_MLS_LOG" == "1" ]]; then
  (
    cd "$REPO_ROOT" || exit 0
    if [[ -x "tools/mls_auto_record.zsh" ]]; then
      mls_cmd=("tools/mls_auto_record.zsh" --source "save.sh" --event "save" \
        --note "save.sh full-cycle hook (autocommit=${SAVE_SH_AUTOCOMMIT})")
      if [[ -n "$SAVE_SH_TARGET_FILE" ]]; then
        mls_cmd+=(--file "$SAVE_SH_TARGET_FILE")
      fi
      "${mls_cmd[@]}" || true
      echo "[save.sh] MLS log recorded via tools/mls_auto_record.zsh"
    else
      echo "[save.sh] SAVE_SH_MLS_LOG=1 set but tools/mls_auto_record.zsh not found - skipping MLS log"
    fi
  )
fi

exit 0
