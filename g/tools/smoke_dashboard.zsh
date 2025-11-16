#!/usr/bin/env zsh
set -euo pipefail
base="http://127.0.0.1:4100"
curl -fsS "$base/health"  | grep -qi '^ok$'
curl -fsS "$base/version" | jq -e '.name=="boss-api" and (.commit|length)>0' >/dev/null
curl -fsS "$base/metrics" | jq -e '.name=="boss-api" and (.pid|tonumber)>=1' >/dev/null
echo "smoke: OK"
