#!/usr/bin/env bash
set -eo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${PORT:-4000}"
BASE_URL="http://127.0.0.1:${PORT}"
LOG_DIR="${ROOT_DIR}/.tmp"
LOG_FILE="${LOG_DIR}/boss-api.out.log"
TIMEOUT="${SMOKE_TIMEOUT:-120}"

mkdir -p "${LOG_DIR}"

# Environment defaults
export PORT="${PORT:-4000}"
export REDIS_URL="${REDIS_URL:-redis://localhost:6379}"
export REDIS_HOST="${REDIS_HOST:-127.0.0.1}"
export REDIS_PORT="${REDIS_PORT:-6379}"
export REDIS_PASSWORD="${REDIS_PASSWORD:-}"
export NODE_ENV="${NODE_ENV:-test}"

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
  
  # If server exited early, show logs
  if [[ -f "${LOG_FILE}" ]] && [[ ${started_server} -eq 1 ]]; then
    echo "[smoke-with-server] ---- boss-api log tail (last 200 lines) ----" >&2
    tail -n 200 "${LOG_FILE}" >&2 || true
    echo "[smoke-with-server] -------------------------------------------" >&2
  fi
}
trap cleanup EXIT INT TERM

# shellcheck disable=SC2329
check_health() {
  # Try both /healthz and /health endpoints
  curl -fsS -m 2 "${BASE_URL}/healthz" >/dev/null 2>&1 || \
  curl -fsS -m 2 "${BASE_URL}/health" >/dev/null 2>&1 || \
  curl -fsS -m 2 "${BASE_URL}/api/health" >/dev/null 2>&1
}

# Wait for port with exponential backoff
wait_for_port() {
  local port=$1
  local max_attempts=${2:-40}
  local base_delay=0.25
  
  for attempt in $(seq 1 ${max_attempts}); do
    if nc -z 127.0.0.1 "${port}" 2>/dev/null; then
      return 0
    fi
    sleep ${base_delay}
  done
  return 1
}

echo "[smoke-with-server] Target base: ${BASE_URL}"

if check_health; then
  echo "[smoke-with-server] Existing boss-api detected; will reuse"
else
  # Install dependencies if package.json exists
  if [[ -f "${ROOT_DIR}/boss-api/package.json" ]]; then
    echo "[smoke-with-server] Installing boss-api dependencies..."
    (cd "${ROOT_DIR}/boss-api" && npm ci --no-audit --no-fund 2>&1 || echo "[smoke-with-server] npm ci failed, continuing...")
  fi
  
  # Try boss-api/server.cjs first, fallback to run/boss_api_stub.cjs
  SERVER_SCRIPT="${ROOT_DIR}/boss-api/server.cjs"
  if [[ ! -f "${SERVER_SCRIPT}" ]]; then
    SERVER_SCRIPT="${ROOT_DIR}/run/boss_api_stub.cjs"
    echo "[smoke-with-server] boss-api/server.cjs not found, using stub: ${SERVER_SCRIPT}"
  fi
  
  if [[ ! -f "${SERVER_SCRIPT}" ]]; then
    echo "[smoke-with-server] ERROR: No boss-api server found (checked boss-api/server.cjs and run/boss_api_stub.cjs)" >&2
    exit 1
  fi
  
  echo "[smoke-with-server] Launching ${SERVER_SCRIPT} (logs: ${LOG_FILE})"
  node "${SERVER_SCRIPT}" >"${LOG_FILE}" 2>&1 &
  server_pid=$!
  started_server=1
  
  # Wait for port to be available
  if ! wait_for_port "${PORT}" 40; then
    echo "[smoke-with-server] ERROR: Port ${PORT} not available after wait" >&2
    if [[ -f "${LOG_FILE}" ]]; then
      echo "[smoke-with-server] ---- boss-api log tail (last 200 lines) ----" >&2
      tail -n 200 "${LOG_FILE}" >&2 || true
      echo "[smoke-with-server] -------------------------------------------" >&2
    fi
    exit 1
  fi

  # Wait for health check with exponential backoff
  for attempt in $(seq 1 40); do
    if ! kill -0 "${server_pid}" 2>/dev/null; then
      echo "[smoke-with-server] ERROR: boss-api exited early (see ${LOG_FILE})" >&2
      if [[ -f "${LOG_FILE}" ]]; then
        echo "[smoke-with-server] ---- boss-api log tail (last 200 lines) ----" >&2
        tail -n 200 "${LOG_FILE}" >&2 || true
        echo "[smoke-with-server] -------------------------------------------" >&2
      fi
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
    if [[ -f "${LOG_FILE}" ]]; then
      echo "[smoke-with-server] ---- boss-api log tail (last 200 lines) ----" >&2
      tail -n 200 "${LOG_FILE}" >&2 || true
      echo "[smoke-with-server] -------------------------------------------" >&2
    fi
    exit 1
  fi
fi

echo "[smoke-with-server] Running scripts/smoke.sh (timeout: ${TIMEOUT}s)"
set +e
timeout "${TIMEOUT}" bash "${ROOT_DIR}/scripts/smoke.sh" || {
  result=$?
  if [[ $result -eq 124 ]]; then
    echo "[smoke-with-server] ERROR: Smoke tests timed out after ${TIMEOUT}s" >&2
  else
    echo "[smoke-with-server] Smoke failed (exit ${result})" >&2
  fi
}
result=${result:-$?}
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
