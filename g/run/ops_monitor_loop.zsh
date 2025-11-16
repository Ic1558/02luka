#!/usr/bin/env zsh
set -euo pipefail

cd "$(dirname "$0")/.."

LOG_DIR="g/logs"
OUT_LOG="${LOG_DIR}/ops_monitor.loop.out.log"
ERR_LOG="${LOG_DIR}/ops_monitor.loop.err.log"

# Pre-flight: verify the monitor script exists
if [[ ! -f "run/ops_atomic_monitor.cjs" ]]; then
  echo "[$(date -u +%FT%TZ)] ERROR: run/ops_atomic_monitor.cjs not found" >> "$ERR_LOG"
  sleep 300
fi

# Main forever loop (5-minute cadence)
while true; do
  ts="$(date -u +%FT%TZ)"
  echo "[$ts] ▶ run monitor" >> "$OUT_LOG"
  /usr/bin/env node run/ops_atomic_monitor.cjs >> "$OUT_LOG" 2>> "$ERR_LOG" || true
  echo "[$ts] ⏳ sleep 300s" >> "$OUT_LOG"
  sleep 300
done
