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

write_if_changed() {
  local target_path="$1"
  local tmp_path="$target_path.tmp.$$"
  cat >"$tmp_path"
  if [ -f "$target_path" ] && cmp -s "$tmp_path" "$target_path"; then
    rm -f "$tmp_path"
  else
    mv "$tmp_path" "$target_path"
  fi
}

API_PORT="${API_PORT:-4001}"
UI_PORT="${UI_PORT:-5173}"
write_if_changed "$AUTO_CONTEXT_DIR/ports.env" <<EOF
API_PORT=$API_PORT
UI_PORT=$UI_PORT
EOF

git_commit_full=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo "unknown")
git_commit_short=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo "unknown")
commit_timestamp=$(git -C "$ROOT" show -s --format=%cI "$git_commit_full" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")
write_if_changed "$AUTO_CONTEXT_DIR/system_snapshot.json" <<EOF
{
  "timestamp": "$commit_timestamp",
  "roots": {
    "repository": ".",
    "auto_context": "run/auto_context"
  },
  "versions": {
    "git_commit": "$git_commit_full",
    "git_short": "$git_commit_short"
  }
}
EOF

capabilities_response="$(curl -fsS "http://127.0.0.1:${API_PORT}/api/capabilities" 2>/dev/null || true)"
if [ -n "$capabilities_response" ]; then
  capabilities_formatted="$(CAPABILITIES_RESPONSE="$capabilities_response" python3 - <<'PY'
import json
import os
raw = os.environ.get("CAPABILITIES_RESPONSE", "")
try:
    data = json.loads(raw)
except Exception:
    data = {"status": "invalid", "raw": raw}
print(json.dumps(data, indent=2, sort_keys=True))
PY
)"
else
  capabilities_formatted="$(cat <<EOF
{
  "status": "unavailable",
  "api_url": "http://127.0.0.1:${API_PORT}/api/capabilities"
}
EOF
)"
fi
write_if_changed "$AUTO_CONTEXT_DIR/capabilities.json" <<EOF
$capabilities_formatted
EOF

shopt -s nullglob
auto_context_files=("$AUTO_CONTEXT_DIR"/*.json "$AUTO_CONTEXT_DIR"/*.env)
shopt -u nullglob
commit_result="no-change"
if [ ${#auto_context_files[@]} -gt 0 ]; then
  git -C "$ROOT" add "${auto_context_files[@]}"
  if ! git -C "$ROOT" diff --cached --quiet; then
    git -C "$ROOT" commit -m "chore(auto_context): update system snapshots"
    commit_result=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo "unknown")
    if [ "${AUTO_PUSH:-0}" = "1" ]; then
      if git -C "$ROOT" push >/dev/null 2>&1; then
        :
      else
        echo "[preflight] auto_context: WARN push failed"
      fi
    fi
  fi
fi

echo "[preflight] auto_context: OK (commit=$commit_result)"
