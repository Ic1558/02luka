#!/usr/bin/env zsh
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
STATE_FILE="$ROOT_DIR/g/state/clc_export_mode.env"
METRICS="$ROOT_DIR/g/metrics/clc_export_mode.json"
BENCH="$ROOT_DIR/g/reports/251021_drive_bench.md"

MODE="unknown"; LOCAL_DIR=""; UPDATED_AT=""
[[ -f "$STATE_FILE" ]] && source "$STATE_FILE"

# Parse last line durations from bench (if exists)
DUR_OFF=""; DUR_LOCAL=""; DUR_DRIVE=""
if [[ -f "$BENCH" ]]; then
  DUR_OFF="$(grep -E '^\| off' "$BENCH"    | awk -F'|' '{print $4}' | xargs)"
  DUR_LOCAL="$(grep -E '^\| local' "$BENCH"| awk -F'|' '{print $4}' | xargs)"
  DUR_DRIVE="$(grep -E '^\| drive' "$BENCH"| awk -F'|' '{print $4}' | xargs)"
fi

cat > "$METRICS.tmp" <<JSON
{
  "updated_at": "$(date -u +%FT%TZ)",
  "mode": "${MODE:-unknown}",
  "local_dir": "${LOCAL_DIR:-}",
  "state_updated_at": "${UPDATED_AT:-}",
  "bench_seconds": {
    "off": "${DUR_OFF:-}",
    "local": "${DUR_LOCAL:-}",
    "drive": "${DUR_DRIVE:-}"
  }
}
JSON
mv -f "$METRICS.tmp" "$METRICS"
echo "Metrics -> $METRICS"
