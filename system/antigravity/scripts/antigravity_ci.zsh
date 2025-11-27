#!/usr/bin/env zsh
# Antigravity CI runner (opt-in). Safe/idempotent.

set -euo pipefail

PROJECT_ROOT="/Users/icmini/02luka/system/antigravity"
LOG_DIR="${PROJECT_ROOT}/logs"
LOG_FILE="${LOG_DIR}/antigravity_ci.log"
PYTEST_TARGET="tests/test_hello.py"
LINT_TARGET="core/hello.py"

mkdir -p "${LOG_DIR}"

{
  echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] Starting Antigravity CI run"
  cd "${PROJECT_ROOT}"

  if [ -f "${LINT_TARGET}" ]; then
    echo "[lint] python -m py_compile ${LINT_TARGET}"
    if ! python -m py_compile "${LINT_TARGET}"; then
      echo "[lint] FAILED"
      exit 1
    fi
    echo "[lint] OK"
  else
    echo "[lint] skipped; target not found"
  fi

  if [ -f "${PYTEST_TARGET}" ]; then
    echo "[tests] pytest ${PYTEST_TARGET}"
    if ! pytest "${PYTEST_TARGET}"; then
      echo "[tests] FAILED"
      exit 1
    fi
    echo "[tests] OK"
  else
    echo "[tests] skipped; target not found"
  fi

  echo "[run] DONE"
} >> "${LOG_FILE}" 2>&1
