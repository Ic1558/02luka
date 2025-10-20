#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${PORT:-4100}"
LOG_FILE="${ROOT_DIR}/test-results/assistant-smoke.log"
mkdir -p "${ROOT_DIR}/test-results"
: > "${LOG_FILE}"

echo "[smoke] Launching API on port ${PORT}" | tee -a "${LOG_FILE}"
PORT="${PORT}" node "${ROOT_DIR}/apps/assistant-api/server.js" >>"${LOG_FILE}" 2>&1 &
SERVER_PID=$!

die() {
  if kill -0 "${SERVER_PID}" 2>/dev/null; then
    kill "${SERVER_PID}" 2>/dev/null || true
  fi
  wait "${SERVER_PID}" 2>/dev/null || true
  echo "[smoke] ${1}" | tee -a "${LOG_FILE}"
  exit 1
}

trap 'die "Aborted"' INT TERM

ready=0
for _ in $(seq 1 30); do
  if curl -fsS "http://127.0.0.1:${PORT}/healthz" >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 0.2
done

if [ "${ready}" -ne 1 ]; then
  die "Server did not start"
fi

echo "[smoke] /healthz" | tee -a "${LOG_FILE}"
curl -fsS "http://127.0.0.1:${PORT}/healthz" | tee -a "${LOG_FILE}" >/dev/null

echo "[smoke] /capabilities" | tee -a "${LOG_FILE}"
curl -fsS "http://127.0.0.1:${PORT}/capabilities" | tee -a "${LOG_FILE}" >/dev/null

echo "[smoke] /rag/query" | tee -a "${LOG_FILE}"
curl -fsS "http://127.0.0.1:${PORT}/rag/query" \
  -H 'Content-Type: application/json' \
  -d '{"query":"test runbook"}' | tee -a "${LOG_FILE}" >/dev/null

echo "[smoke] /memory/stats" | tee -a "${LOG_FILE}"
curl -fsS "http://127.0.0.1:${PORT}/memory/stats" | tee -a "${LOG_FILE}" >/dev/null

kill "${SERVER_PID}" 2>/dev/null || true
wait "${SERVER_PID}" 2>/dev/null || true

echo "[smoke] Completed" | tee -a "${LOG_FILE}"
