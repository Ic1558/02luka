#!/usr/bin/env zsh
set -euo pipefail

BASE="${LUKA_HOME:-$HOME/02luka}"
QUERY_TOOL="${BASE}/tools/rag_query.zsh"
TELEMETRY_DIR="${BASE}/telemetry_unified/rag"
STATUS_LOG="${TELEMETRY_DIR}/rag.probe.status.jsonl"
LATENCY_LOG="${TELEMETRY_DIR}/rag.probe.latency.jsonl"
PROBE_PROMPT=${1:-"system probe: phase14.4 healthcheck"}

mkdir -p "${TELEMETRY_DIR}"

if [[ ! -x "${QUERY_TOOL}" ]]; then
  echo "rag_probe: missing query tool ${QUERY_TOOL}" >&2
  exit 78
fi

zmodload zsh/datetime
START=${EPOCHREALTIME}
OUTPUT=""
STATUS="ok"
EXIT_CODE=0

if OUTPUT="$(${QUERY_TOOL} "${PROBE_PROMPT}" 2>&1)"; then
  STATUS="ok"
else
  EXIT_CODE=$?
  STATUS="error"
fi

END=${EPOCHREALTIME}
export START END

LATENCY=$(python3 - <<'PY'
import os
start = float(os.environ["START"])
end = float(os.environ["END"])
print(f"{end - start:.6f}")
PY
)

TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
RUN_ID=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid)

cat <<JSON >> "${STATUS_LOG}"
{"ts": "${TS}", "run": "${RUN_ID}", "status": "${STATUS}", "exit_code": ${EXIT_CODE}}
JSON

cat <<JSON >> "${LATENCY_LOG}"
{"ts": "${TS}", "run": "${RUN_ID}", "latency_s": ${LATENCY}}
JSON

if [[ "${STATUS}" != "ok" ]]; then
  echo "${OUTPUT}" >&2
  exit ${EXIT_CODE}
fi

print -- "${OUTPUT}"
