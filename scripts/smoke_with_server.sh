#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${PORT:-4000}"
BASE_URL="http://127.0.0.1:${PORT}"
LOG_DIR="${ROOT_DIR}/.tmp"
LOG_FILE="${LOG_DIR}/boss-api.out.log"

mkdir -p "${LOG_DIR}"

started_server=0
server_pid=""

# shellcheck disable=SC2329
cleanup() {
  if [[ "${started_server}" -eq 1 ]] && [[ -n "${server_pid}" ]]; then
    if kill -0 "${server_pid}" 2>/dev/null; then
      echo "[smoke-with-server] Stopping boss-api (pid ${server_pid})"
      kill "${server_pid}" 2>/dev/null || true
      wait "${server_pid}" 2>/dev/null || true
    fi
  fi
}
trap cleanup EXIT INT TERM

# shellcheck disable=SC2329
check_health() {
  curl -fsS -m 2 "${BASE_URL}/healthz" >/dev/null 2>&1
}

echo "[smoke-with-server] Target base: ${BASE_URL}"

if check_health; then
  echo "[smoke-with-server] Existing boss-api detected; will reuse"
else
  echo "[smoke-with-server] Launching boss-api/server.cjs (logs: ${LOG_FILE})"
  node "${ROOT_DIR}/boss-api/server.cjs" >"${LOG_FILE}" 2>&1 &
  server_pid=$!
  started_server=1

  for attempt in $(seq 1 40); do
    if ! kill -0 "${server_pid}" 2>/dev/null; then
      echo "[smoke-with-server] ERROR: boss-api exited early (see ${LOG_FILE})" >&2
      exit 1
    fi
    if check_health; then
      echo "[smoke-with-server] boss-api ready (attempt ${attempt})"
      break
    fi
    sleep 0.25
  done

  if ! check_health; then
    echo "[smoke-with-server] ERROR: boss-api not healthy after wait (see ${LOG_FILE})" >&2
    exit 1
  fi
fi

echo "[smoke-with-server] Running scripts/smoke.sh"
set +e
bash "${ROOT_DIR}/scripts/smoke.sh"
result=$?
set -e

if [[ ${result} -ne 0 ]]; then
  echo "[smoke-with-server] Smoke failed (exit ${result}). Boss API logs: ${LOG_FILE}" >&2
  if [[ -f "${LOG_FILE}" ]]; then
    echo "[smoke-with-server] ---- boss-api log tail (last 200 lines) ----" >&2
    tail -n 200 "${LOG_FILE}" >&2 || true
    echo "[smoke-with-server] -------------------------------------------" >&2
  fi
else
  echo "[smoke-with-server] Smoke succeeded"
fi

exit ${result}


