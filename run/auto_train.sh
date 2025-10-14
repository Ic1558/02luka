#!/usr/bin/env bash
set -euo pipefail

RUN_ID="${PAULA_RUN_ID:-unknown}"
STRATEGY="default"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --strategy)
      shift
      if [[ $# -gt 0 ]]; then
        STRATEGY="$1"
      fi
      ;;
    *)
      echo "[warn] Unknown argument: $1" >&2
      ;;
  esac
  shift || true
done

echo "[info] Auto-train job ${RUN_ID} using strategy '${STRATEGY}'"
echo '[info] Simulating training pipeline...'
sleep 1
echo '[info] Training complete.'
