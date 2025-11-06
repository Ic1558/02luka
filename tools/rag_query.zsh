#!/usr/bin/env zsh
set -euo pipefail

BASE="${LUKA_HOME:-$HOME/02luka}"
CONFIG="${BASE}/config/rag_pipeline.yaml"
TELEMETRY_DIR="${BASE}/telemetry_unified/rag"
SESSION_LOG="${TELEMETRY_DIR}/rag.ctx.session.jsonl"
LATENCY_LOG="${TELEMETRY_DIR}/rag.ctx.latency.jsonl"

if [[ ! -f "${CONFIG}" ]]; then
  echo "rag_query: missing config ${CONFIG}" >&2
  exit 78
fi

if [[ $# -eq 0 ]]; then
  echo "Usage: $(basename "$0") \"question...\"" >&2
  exit 64
fi

mkdir -p "${TELEMETRY_DIR}"

zmodload zsh/datetime
START=${EPOCHREALTIME}
QUERY="$*"

# Simulated answer – replace with real pipeline call when components land.
ANSWER="(simulated) RAG response for: ${QUERY}"

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
SESSION_ID=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid)

cat <<JSON >> "${SESSION_LOG}"
{"ts": "${TS}", "session": "${SESSION_ID}", "query": "${QUERY}", "config": "${CONFIG}"}
JSON

cat <<JSON >> "${LATENCY_LOG}"
{"ts": "${TS}", "session": "${SESSION_ID}", "latency_s": ${LATENCY}}
JSON

print -- "${ANSWER}"
