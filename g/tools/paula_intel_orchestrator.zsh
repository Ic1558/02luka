#!/usr/bin/env zsh
set -euo pipefail

# Phase 6.1: Paula Intel Orchestrator
# Coordinates: crawler → analytics → Redis/shared memory update

SOT="${LUKA_SOT:-/Users/icmini/02luka}"
REDIS_HOST="${REDIS_HOST:-localhost}"
REDIS_PORT="${REDIS_PORT:-6379}"
# Prefer new pass; fallback to old if env not set
REDIS_PASSWORD="${REDIS_PASSWORD:-gggclukaic}"
[[ -n "${REDIS_ALT_PASSWORD:-}" ]] && REDIS_PASSWORD="$REDIS_ALT_PASSWORD"

LOG_DIR="$SOT/logs"
mkdir -p "$LOG_DIR"

# Use mktemp for log file to prevent corruption on concurrent runs
LOG_TMP=$(mktemp "$LOG_DIR/paula_intel_orchestrator.XXXXXX.log")
LOG="$LOG_DIR/paula_intel_orchestrator.log"

ts() { date -Iseconds; }

# Function to append to log safely
log_msg() {
  echo "$(ts) $1" >> "$LOG_TMP"
}

log_msg "START paula_intel"

# Run crawler
CRAWL_OUT=""
if [[ -x "$SOT/tools/paula_data_crawler.py" ]]; then
  CRAWL_OUT="$("$SOT/tools/paula_data_crawler.py" 2>&1 || true)"
  log_msg "crawler_out: $CRAWL_OUT"
else
  log_msg "ERROR: paula_data_crawler.py not found or not executable"
  mv "$LOG_TMP" "$LOG"
  exit 1
fi

# Run predictive analytics
PRED_OUT=""
if [[ -x "$SOT/tools/paula_predictive_analytics.py" ]]; then
  PRED_OUT="$("$SOT/tools/paula_predictive_analytics.py" 2>&1 || true)"
  log_msg "predictive_out: $PRED_OUT"
else
  log_msg "ERROR: paula_predictive_analytics.py not found or not executable"
  mv "$LOG_TMP" "$LOG"
  exit 1
fi

# Check if bias file was created
if [[ -f "$PRED_OUT" ]]; then
  INSIGHT="$(cat "$PRED_OUT")"
  
  # Extract summary for Redis (using Python for JSON processing)
  SUMMARY="$(echo "$INSIGHT" | /usr/bin/python3 - <<'PY'
import sys
import json

try:
    d = json.load(sys.stdin)
    summary = {
        "symbol": d.get("symbol", "unknown"),
        "bias": d.get("bias", "flat"),
        "trend_confidence": d.get("trend_confidence", 0.0),
        "predicted_move_pct": d.get("predicted_move_pct", 0.0),
        "suggestion": d.get("position_suggestion", "wait"),
        "ts": d.get("timestamp", "")
    }
    print(json.dumps(summary))
except Exception as e:
    print("{}")
PY
  )"
  
  # Update Redis (ignore failures gracefully)
  if command -v redis-cli >/dev/null 2>&1; then
    if redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -a "$REDIS_PASSWORD" PING >/dev/null 2>&1; then
      (redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -a "$REDIS_PASSWORD" \
        HSET memory:agents:paula status active last_update "$(ts)" insight "$SUMMARY" >/dev/null 2>&1) || log_msg "WARNING: Redis HSET failed"
      
      (redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -a "$REDIS_PASSWORD" \
        PUBLISH memory:updates "{\"agent\":\"paula\",\"event\":\"context_update\",\"ts\":\"$(ts)\"}" >/dev/null 2>&1) || log_msg "WARNING: Redis PUBLISH failed"
      
      log_msg "updated redis + published"
    else
      log_msg "WARNING: Redis not available (PING failed)"
    fi
  else
    log_msg "WARNING: redis-cli not found"
  fi
else
  log_msg "WARNING: Bias file not created: $PRED_OUT"
fi

log_msg "DONE paula_intel"

# Move temp log to final location atomically
mv "$LOG_TMP" "$LOG"
