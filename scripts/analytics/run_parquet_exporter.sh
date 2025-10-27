#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
NODE_BIN="${NODE_BIN:-node}"
EXPORTER_SCRIPT="${REPO_ROOT}/run/parquet_exporter.cjs"
LOG_DIR="${PARQUET_EXPORTER_LOG_DIR:-${REPO_ROOT}/logs/parquet}"
mkdir -p "${LOG_DIR}"

if [[ ! -x "${NODE_BIN}" && -z "$(command -v "${NODE_BIN}" 2>/dev/null)" ]]; then
  echo "[parquet-exporter] ERROR: node runtime not found (${NODE_BIN})" >&2
  exit 127
fi

if [[ ! -f "${EXPORTER_SCRIPT}" ]]; then
  echo "[parquet-exporter] ERROR: exporter script not found at ${EXPORTER_SCRIPT}" >&2
  exit 1
fi

STAMP="$(date -u +"%Y%m%dT%H%M%SZ")"
LOG_FILE="${LOG_DIR}/run_${STAMP}.log"

run_command() {
  local resolved_node
  if [[ -x "${NODE_BIN}" ]]; then
    resolved_node="${NODE_BIN}"
  else
    resolved_node="$(command -v "${NODE_BIN}")"
  fi

  if [[ -z "${resolved_node}" ]]; then
    echo "[parquet-exporter] ERROR: unable to resolve node binary (${NODE_BIN})" >&2
    return 127
  fi

  "${resolved_node}" "${EXPORTER_SCRIPT}" "$@"
}

{
  echo "[parquet-exporter] ${STAMP} :: starting parquet export"
  run_command "$@"
  status=$?
  echo "[parquet-exporter] ${STAMP} :: exporter exit status ${status}"
  exit ${status}
} 2>&1 | tee "${LOG_FILE}"

status=${PIPESTATUS[0]}

if [[ ${status} -ne 0 ]]; then
  echo "[parquet-exporter] run failed (status=${status}). See log: ${LOG_FILE}" >&2
else
  echo "[parquet-exporter] run completed successfully. Log: ${LOG_FILE}"
fi

exit ${status}
