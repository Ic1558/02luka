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
