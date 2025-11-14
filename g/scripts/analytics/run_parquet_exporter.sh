#!/usr/bin/env zsh
set -euo pipefail

# Parquet Exporter Runner
# Phase 7.8 - Data Analytics Integration

REPO_ROOT="${HOME}/02luka"
EXPORTER="${REPO_ROOT}/run/parquet_exporter.cjs"
LOG_DIR="${REPO_ROOT}/g/logs"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Logging
LOG_FILE="${LOG_DIR}/parquet_exporter.log"
ERR_FILE="${LOG_DIR}/parquet_exporter.err.log"

# Timestamp
TS="$(date -u +%FT%TZ)"

echo "[$TS] Starting Parquet export..." | tee -a "$LOG_FILE"

# Change to repo root
cd "$REPO_ROOT"

# Run exporter
if /usr/bin/env node "$EXPORTER" >> "$LOG_FILE" 2>> "$ERR_FILE"; then
  echo "[$TS] ✅ Parquet export complete" | tee -a "$LOG_FILE"
  exit 0
else
  EXIT_CODE=$?
  echo "[$TS] ❌ Parquet export failed (exit code: $EXIT_CODE)" | tee -a "$ERR_FILE"
  exit $EXIT_CODE
fi
