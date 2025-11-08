#!/usr/bin/env zsh
set -euo pipefail
export LUKA_HOME="${LUKA_HOME:-$HOME/02luka}"
# require yq, jq
command -v yq >/dev/null || { echo "yq required"; exit 1; }
node hub/telemetry_merge.mjs
echo "OK: telemetry routed & hub/telemetry_snapshot.json updated"
