#!/usr/bin/env zsh
set -euo pipefail

##
## test_save_full_cycle.zsh
##
## Purpose:
##   - Provide a manual full-cycle test for save.sh:
##       edit → save.sh → (optional) auto-commit → (optional) MLS log
##   - Keep it lane-agnostic (CLS / CLC both can call it the same way)
##
## Usage:
##   tools/test_save_full_cycle.zsh [lane]
##   lane: "cls" | "clc" | anything (for logging only)
##

LANE="${1:-unknown}"

SCRIPT_DIR="$(cd "$(dirname "${(%):-%N}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

TMP_DIR="${REPO_ROOT}/g/tmp"
mkdir -p "${TMP_DIR}"

TARGET_FILE="${TMP_DIR}/save_sh_full_cycle_test.txt"

echo "[test_save_full_cycle] repo=${REPO_ROOT}"
echo "[test_save_full_cycle] lane=${LANE}"
echo "[test_save_full_cycle] target=${TARGET_FILE}"

timestamp="$(date '+%Y-%m-%dT%H:%M:%S%z' 2>/dev/null || echo 'unknown-time')"
echo "save.sh full-cycle test (${timestamp}) lane=${LANE}" >> "${TARGET_FILE}"

echo "[test_save_full_cycle] step 1: baseline save.sh (no hooks)"
(
  cd "${REPO_ROOT}"
  SAVE_SH_TARGET_FILE="${TARGET_FILE}" \
    SAVE_SH_AUTOCOMMIT=0 \
    SAVE_SH_MLS_LOG=0 \
    tools/save.sh
) || echo "[test_save_full_cycle] baseline run exited non-zero (ok for manual debugging)"

echo "[test_save_full_cycle] step 2: save.sh with MLS only"
(
  cd "${REPO_ROOT}"
  SAVE_SH_TARGET_FILE="${TARGET_FILE}" \
    SAVE_SH_AUTOCOMMIT=0 \
    SAVE_SH_MLS_LOG=1 \
    tools/save.sh
) || echo "[test_save_full_cycle] MLS run exited non-zero (ok for manual debugging)"

echo "[test_save_full_cycle] step 3: save.sh with auto-commit + MLS"
(
  cd "${REPO_ROOT}"
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    SAVE_SH_TARGET_FILE="${TARGET_FILE}" \
      SAVE_SH_AUTOCOMMIT=1 \
      SAVE_SH_MLS_LOG=1 \
      tools/save.sh
  else
    echo "[test_save_full_cycle] not in git repo, skipping auto-commit phase"
  fi
) || echo "[test_save_full_cycle] autocommit run exited non-zero (ok for manual debugging)"

echo "[test_save_full_cycle] done."

REPORT_DIR="${REPO_ROOT}/g/reports/system"
mkdir -p "${REPORT_DIR}"
REPORT_FILE="${REPORT_DIR}/save_sh_full_cycle_test_report.md"

{
  echo "# save.sh Full-Cycle Test Report"
  echo
  echo "- Time: ${timestamp}"
  echo "- Lane: ${LANE}"
  echo "- Repo: ${REPO_ROOT}"
  echo "- Target file: ${TARGET_FILE}"
  echo
  echo "## Steps"
  echo "1. Baseline save.sh (no hooks)"
  echo "2. save.sh with MLS logging only"
  echo "3. save.sh with auto-commit + MLS logging (if git repo)"
  echo
  echo "## Notes"
  echo "- This script does not fail CI; it is intended for manual verification in CLS/CLC."
  echo "- Any MLS entries are handled by tools/mls_auto_record.zsh if present."
} > "${REPORT_FILE}"

chmod 644 "${TARGET_FILE}"

echo "[test_save_full_cycle] report written to ${REPORT_FILE}"
