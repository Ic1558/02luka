#!/usr/bin/env bash
set -euo pipefail

PORT="${PORT:-7217}"
Q="$*"
if [[ -z "$Q" ]]; then
  echo "usage: kim_rag.sh <question>" >&2
  exit 1
fi

curl -sS -X POST "http://127.0.0.1:${PORT}/query" \
  -H "content-type: application/json" \
  -d @- <<JSON
{"agent":"kim","q":"${Q}","top_k":5}
JSON
