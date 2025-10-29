#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_RESULTS_DIR="${ROOT_DIR}/test-results"
mkdir -p "${TEST_RESULTS_DIR}"

LOG_FILE="${TEST_RESULTS_DIR}/assistant-smoke.log"
BOSS_API_LOG="${TEST_RESULTS_DIR}/boss-api-smoke.log"

SERVER_PID=""
BOSS_API_PID=""

: > "${LOG_FILE}"

cleanup() {
  if [[ -n "${SERVER_PID}" ]] && kill -0 "${SERVER_PID}" 2>/dev/null; then
    kill "${SERVER_PID}" 2>/dev/null || true
    wait "${SERVER_PID}" 2>/dev/null || true
  fi

  if [[ -n "${BOSS_API_PID}" ]] && kill -0 "${BOSS_API_PID}" 2>/dev/null; then
    kill "${BOSS_API_PID}" 2>/dev/null || true
    wait "${BOSS_API_PID}" 2>/dev/null || true
  fi
}

trap cleanup EXIT

die() {
  echo "[smoke] ${1}" | tee -a "${LOG_FILE}"
  exit 1
}

trap 'die "Aborted"' INT TERM

BASE="${OPS_ATOMIC_URL:-}"
if [[ -z "${BASE}" ]]; then
  BASE="http://127.0.0.1:4000"
  : > "${BOSS_API_LOG}"
  echo "[smoke] Starting local Boss API stub at ${BASE}" | tee -a "${BOSS_API_LOG}"
  node "${ROOT_DIR}/boss-api/server.cjs" >>"${BOSS_API_LOG}" 2>&1 &
  BOSS_API_PID=$!

  ready=0
  for _ in $(seq 1 25); do
    if curl -fsS "${BASE}/healthz" >/dev/null 2>&1; then
      ready=1
      break
    fi
    sleep 0.2
  done

  if [[ "${ready}" -ne 1 ]]; then
    die "Boss API stub did not start"
  fi
else
  BASE="${BASE%/}"
fi

echo "🧪 Smoke target: $BASE"

fail=0

check() {
  local path="$1" expect="$2"
  code=$(curl -sS -o /dev/null -w "%{http_code}" "$BASE$path" || true)
  echo "→ $path  [$code]"
  [[ "$code" == "$expect" ]] || fail=$((fail+1))
}

# CI-friendly checks (no local UI needed)
check "/healthz" 200
check "/api/reports/summary" 200

if [[ "${OPS_GATE_OVERRIDE:-0}" == "1" ]]; then
  echo "⚠️  Gate override ON — ignoring failures"; exit 0
fi

if [[ $fail -gt 0 ]]; then
  echo "❌ Smoke failed ($fail) checks"; exit 1
fi
echo "✅ Smoke passed"
PORT="${PORT:-4100}"
: > "${LOG_FILE}"

echo "[smoke] Launching API on port ${PORT}" | tee -a "${LOG_FILE}"
PORT="${PORT}" node "${ROOT_DIR}/apps/assistant-api/server.js" >>"${LOG_FILE}" 2>&1 &
SERVER_PID=$!

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
