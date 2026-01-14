#!/usr/bin/env zsh
set -euo pipefail

ROOT="${LUKA_ROOT:-$HOME/02luka}"
BASE_WS="/Users/icmini/02luka_ws"
INPUT_PATH="$BASE_WS/g/telemetry/lac_metrics_summary_latest.test.json"
INGEST_SCRIPT="$ROOT/tools/telemetry/lac_metrics_mls_ingest.py"
RD_DIR="$BASE_WS/bridge/inbox/rd"

mkdir -p "${BASE_WS}/g/telemetry" "${RD_DIR}"

TS="$(date +%Y-%m-%dT%H:%M:%S%z)"
DATE_ONLY="${TS%%T*}"
SAFE_TS="${TS//:/}"
SAFE_TS="${SAFE_TS//+/}"
SAFE_TS="${SAFE_TS//./}"
ALERT_PATH="$RD_DIR/LAC-telemetry-alert-${SAFE_TS}.json"

cat > "$INPUT_PATH" <<JSON
{
  "generated_at": "${TS}",
  "window": {"since_seconds": 86400, "cutoff": "${TS}"},
  "totals": {"completed": 10, "error": 1, "total": 11},
  "window_counts": {"completed": 10, "error": 1, "total": 11},
  "window_error_rate_pct": 9.1,
  "duration_ms": {"avg_ms": 300, "p50_ms": 250, "p95_ms": 900, "min_ms": 50, "max_ms": 1200},
  "queue_depth": {"min": 0, "avg": 1.5, "max": 4},
  "last_events": []
}
JSON

if [[ ! -f "$INGEST_SCRIPT" ]]; then
  echo "Missing ingest script: $INGEST_SCRIPT" >&2
  exit 1
fi

python3 "$INGEST_SCRIPT" --input "$INPUT_PATH" || true

if [[ -f "$ALERT_PATH" ]]; then
  echo "OK: alert generated for ${DATE_ONLY}"
  echo "Alert: $ALERT_PATH"
  exit 0
fi

echo "ERROR: expected alert not found at $ALERT_PATH" >&2
exit 1
