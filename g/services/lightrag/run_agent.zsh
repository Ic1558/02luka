#!/usr/bin/env zsh
set -euo pipefail

AGENT="${1:?usage: run_agent.zsh <agent>}" 
BASE="$HOME/02luka/g/services/lightrag"
CFG="$BASE/config/agents.yaml"
APP="$BASE/app/service:app"

if [[ ! -f "$CFG" ]]; then
  echo "config missing: $CFG" >&2
  exit 1
fi

PORT=$(python3 - <<'PY' "$CFG" "$AGENT"
import sys
import yaml
from pathlib import Path
cfg = yaml.safe_load(Path(sys.argv[1]).read_text()) or {}
data = (cfg.get("agents") or {}).get(sys.argv[2])
if not data:
    raise SystemExit(1)
print(data.get("port", ""))
PY
) || { echo "unknown agent: $AGENT" >&2; exit 1; }

if [[ -z "$PORT" ]]; then
  echo "no port configured for $AGENT" >&2
  exit 1
fi

export LT_BASE="$BASE"

exec "$BASE/.venv/bin/uvicorn" "$APP" --host "0.0.0.0" --port "$PORT"
