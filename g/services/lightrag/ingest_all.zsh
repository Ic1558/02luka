#!/usr/bin/env zsh
set -euo pipefail

BASE="${BASE:-$HOME/02luka/g/services/lightrag}"
CFG="$BASE/config/agents.yaml"
API_HOST="${LT_API_HOST:-127.0.0.1}"

if [[ ! -f "$CFG" ]]; then
  echo "config missing: $CFG" >&2
  exit 1
fi

specs=($(python3 - <<'PY' "$CFG"
import sys
import yaml
from pathlib import Path
cfg = yaml.safe_load(Path(sys.argv[1]).read_text()) or {}
for name, data in (cfg.get("agents") or {}).items():
    port = data.get("port")
    if port is None:
        continue
    print(f"{name}:{port}")
PY
))

if (( ${#specs} == 0 )); then
  echo "no agents defined" >&2
  exit 1
fi

for spec in $specs; do
  agent=${spec%%:*}
  port=${spec##*:}
  echo "[*] ingest $agent -> http://$API_HOST:$port/ingest"
  curl -sS -X POST "http://$API_HOST:$port/ingest" \
    -H 'content-type: application/json' \
    -d '{"agent":"'$agent'"}' || echo "    ! failed for $agent"
  echo
done
