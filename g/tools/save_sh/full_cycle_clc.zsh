#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_REPO="$(cd "${SCRIPT_DIR}/../.." && pwd)"
REPO_ROOT=${SAVE_SH_SOT_ROOT:-${SAVE_SH_REPO_ROOT:-$DEFAULT_REPO}}
cd "$REPO_ROOT"

TEST_DIR="$REPO_ROOT/logs/save_sh/tests"
mkdir -p "$TEST_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
TEST_LOG="$TEST_DIR/full_cycle_clc_${TIMESTAMP}.log"

echo "=== save.sh full-cycle test (CLC lane) ==="
BEFORE_STATUS=$(git status --short)
FILTERED_BEFORE=$(printf '%s\n' "$BEFORE_STATUS" | grep -Ev '^\?\? (mls/ledger/|logs/save_sh/)' || true)
if [[ -z "$BEFORE_STATUS" ]]; then
  BEFORE_STATE="clean"
else
  BEFORE_STATE="dirty"
fi

set +e
set -o pipefail
SAVE_SH_LANE="CLC" LUKA_MLS_AUTO_RECORD=1 bash "$REPO_ROOT/tools/save.sh" | tee "$TEST_LOG"
EXIT_CODE=${PIPESTATUS[0]}
set -e

after_status=$(git status --short)
FILTERED_AFTER=$(printf '%s\n' "$after_status" | grep -Ev '^\?\? (mls/ledger/|logs/save_sh/)' || true)
if [[ -z "$after_status" ]]; then
  AFTER_STATE="clean"
else
  AFTER_STATE="dirty"
fi
MLS_DAY=$(TZ=Asia/Bangkok date +%Y-%m-%d)
MLS_LEDGER="$REPO_ROOT/mls/ledger/${MLS_DAY}.jsonl"
MLS_MARKER="save.sh full-cycle (CLC)"
MLS_RESULT="missing-ledger"
if [[ -f "$MLS_LEDGER" ]]; then
  if grep -Fq "$MLS_MARKER" "$MLS_LEDGER"; then
    MLS_RESULT="recorded"
  else
    MLS_RESULT="not-found"
  fi
fi

TEST_STATUS=$EXIT_CODE
if [[ $TEST_STATUS -eq 0 && "$FILTERED_BEFORE" != "$FILTERED_AFTER" ]]; then
  echo "⚠️  Git status changed after save.sh run" >&2
  TEST_STATUS=4
fi
if [[ $TEST_STATUS -eq 0 && "$MLS_RESULT" != "recorded" ]]; then
  echo "⚠️  MLS record not detected for CLC lane" >&2
  TEST_STATUS=5
fi

cat <<SUMMARY
---
Results:
  save.sh exit code : $EXIT_CODE
  git status before : $BEFORE_STATE
  git status after  : $AFTER_STATE
  MLS ledger        : $MLS_RESULT
  log file          : ${TEST_LOG#$REPO_ROOT/}
SUMMARY

if [[ $TEST_STATUS -eq 0 ]]; then
  echo "✅ CLC full-cycle test passed"
else
  echo "❌ CLC full-cycle test failed (code $TEST_STATUS)"
fi

exit $TEST_STATUS
