#!/usr/bin/env zsh
set -euo pipefail
source ~/.config/02luka/rag.env 2>/dev/null || true
BASE="$HOME/02luka/g/rag"
VEN="$BASE/.venv/bin"
LOG="$HOME/02luka/logs/rag_refresh_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1
echo "== refresh index =="
"$VEN/python" "$BASE/server.py"  >/dev/null 2>&1 || true
curl -s -X POST http://127.0.0.1:8765/refresh >/dev/null 2>&1 || {
  "$VEN/python" - <<'PY'
from server import read_cfg, refresh_index
print(refresh_index(read_cfg()))
PY
}
