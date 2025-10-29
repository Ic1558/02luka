#!/usr/bin/env zsh
set -euo pipefail
ROOT="$HOME/02luka"
LOG="$ROOT/g/logs/parquet_exporter.log"
: ${DUCKDB_BIN:=duckdb}
export DUCKDB_BIN

mkdir -p "$ROOT/g/logs"

echo "[${(%):-%D{%Y-%m-%d %H:%M:%S}}] start parquet exporter" | tee -a "$LOG"
node "$ROOT/run/parquet_exporter.cjs" | tee -a "$LOG"
echo "[${(%):-%D{%Y-%m-%d %H:%M:%S}}] done" | tee -a "$LOG"
