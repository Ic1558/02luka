#!/usr/bin/env zsh
set -euo pipefail
base="http://127.0.0.1:4100"
curl -fsS "$base/metrics.prom" | grep -q "^bossapi_up 1$"
echo "smoke(prom): OK"
