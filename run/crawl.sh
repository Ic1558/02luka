#!/usr/bin/env bash
set -euo pipefail

RUN_ID="${PAULA_RUN_ID:-unknown}"
JOB_TYPE="${PAULA_JOB_TYPE:-crawl}"

seeds=()
max_pages=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --seed)
      shift
      if [[ $# -gt 0 ]]; then
        seeds+=("$1")
      fi
      ;;
    --max-pages)
      shift
      if [[ $# -gt 0 ]]; then
        max_pages="$1"
      fi
      ;;
    *)
      echo "[warn] Unrecognized argument: $1" >&2
      ;;
  esac
  shift || true
done

printf '[info] Paula crawl job (%s) starting for %s\n' "$RUN_ID" "$JOB_TYPE"
if [[ ${#seeds[@]} -gt 0 ]]; then
  printf '[info] Seeds: %s\n' "${seeds[*]}"
else
  echo '[info] No seeds provided; nothing to crawl.'
fi
if [[ -n "$max_pages" ]]; then
  printf '[info] Max pages: %s\n' "$max_pages"
fi

echo '[info] Simulating crawl work...'
# Fast deterministic workload placeholder.
sleep 1

echo '[info] Crawl pipeline complete.'
