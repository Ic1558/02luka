#!/usr/bin/env bash
set -euo pipefail
ROOT="${SOT_PATH:-$(pwd)}"

# 1) Generate latest system map (best-effort)
python3 "$ROOT/g/tools/render_system_map.py" 2>/dev/null || true

# 2) Validate mapping (warn only; Codex should still proceed)
if bash "$ROOT/g/tools/mapping_drift_guard.sh" --validate >/dev/null 2>&1; then
  echo "[02luka] mapping validation: OK"
else
  echo "[02luka] mapping validation: WARN (continue)"
fi

# 3) Print key namespaces to log (helps Codex reasoning)
if [ -f "$ROOT/f/ai_context/mapping.json" ]; then
  echo "[02luka] namespaces:"
  jq -r '.namespaces | to_entries[] | .key + ": " + ( .value | keys | join(",") )' "$ROOT/f/ai_context/mapping.json" || true
fi

echo "[02luka] preflight ready."

# Check master prompt presence
if [ ! -s ".codex/templates/master_prompt.md" ]; then
  echo "[preflight] WARN: .codex/templates/master_prompt.md missing or empty"
else
  echo "[preflight] master_prompt: OK"
fi

AUTO_CONTEXT_DIR="$ROOT/run/auto_context"
mkdir -p "$AUTO_CONTEXT_DIR"

API_PORT_VALUE="${PORT:-4000}"
UI_PORT_VALUE="${UI_PORT:-5173}"
cat <<EOF >"$AUTO_CONTEXT_DIR/ports.env"
API_PORT=$API_PORT_VALUE
UI_PORT=$UI_PORT_VALUE
EOF

SYSTEM_SNAPSHOT="$AUTO_CONTEXT_DIR/system_snapshot.json"
ROOT_DIR="$ROOT" SYSTEM_SNAPSHOT="$SYSTEM_SNAPSHOT" python3 - <<'PY'
import json
import os
import platform
from datetime import datetime, timezone
from pathlib import Path
import subprocess

root = Path(os.environ.get('ROOT_DIR', '.')).resolve()

def cmd_output(cmd):
    try:
        return subprocess.check_output(cmd, stderr=subprocess.DEVNULL, text=True).strip()
    except Exception:
        return None

snapshot = {
    "generated_at": datetime.now(timezone.utc).isoformat(),
    "repo": str(root.name),
    "git_head": cmd_output(['git', '-C', str(root), 'rev-parse', 'HEAD']),
    "python_version": cmd_output(['python3', '--version']),
    "node_version": cmd_output(['node', '--version']),
    "platform": platform.platform()
}

Path(os.environ['SYSTEM_SNAPSHOT']).write_text(json.dumps(snapshot, indent=2) + "\n", encoding='utf-8')
PY

CAPABILITIES_PATH="$AUTO_CONTEXT_DIR/capabilities.json"
CAPABILITIES_URL="http://127.0.0.1:${API_PORT_VALUE}/api/capabilities"
if command -v curl >/dev/null 2>&1; then
  if curl -fsS "$CAPABILITIES_URL" -o "$CAPABILITIES_PATH" 2>/dev/null; then
    echo "[preflight] capabilities snapshot captured"
  else
    cat <<'JSON' >"$CAPABILITIES_PATH"
{"error":"capabilities-endpoint-unreachable"}
JSON
  fi
else
  cat <<'JSON' >"$CAPABILITIES_PATH"
{"error":"curl-not-available"}
JSON
fi

if [[ "${AUTO_PUSH:-0}" == "1" ]]; then
  git -C "$ROOT" add "$AUTO_CONTEXT_DIR/ports.env" "$SYSTEM_SNAPSHOT" "$CAPABILITIES_PATH" 2>/dev/null || true
  if ! git -C "$ROOT" diff --cached --quiet 2>/dev/null; then
    git -C "$ROOT" commit -m "chore(auto_context): update system snapshots" || true
    if [[ "${NO_PUSH:-0}" != "1" ]]; then
      git -C "$ROOT" push || echo "[preflight] WARN: auto push failed"
    fi
  fi
fi
