#!/usr/bin/env zsh
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "$0")" && pwd)
REPO_BASE="$(cd "$SCRIPT_DIR/../.." && pwd)"
DEFAULT_BASE="${LUKA_SOT:-$HOME/02luka}"
if [[ -n "${LUKA_SOT:-}" && -d "${LUKA_SOT}" ]]; then
  BASE="$LUKA_SOT"
elif [[ -f "$REPO_BASE/g/tools/lpe_worker.zsh" ]]; then
  BASE="$REPO_BASE"
elif [[ -d "$DEFAULT_BASE" ]]; then
  BASE="$DEFAULT_BASE"
else
  BASE="$REPO_BASE"
fi
WORKER="$BASE/g/tools/lpe_worker.zsh"
TARGET_FILE="$BASE/g/tmp/lpe_smoke_test.txt"
LEDGER_DIR="$BASE/mls/ledger"
WO_ID="LPE-SMOKE-$(date +%s)"
PATCH_FILE="$(mktemp)"
WO_FILE="$BASE/bridge/inbox/LPE/${WO_ID}.json"

mkdir -p "$BASE/g/tmp" "$BASE/bridge/inbox/LPE" "$LEDGER_DIR"

generate_patch() {
  cat > "$PATCH_FILE" <<'PATCH'
meta:
  source: "smoke"
  reason: "LPE smoke test"
ops:
  - path: "g/tmp/lpe_smoke_test.txt"
    mode: "append"
    content: |
      LPE smoke test line
PATCH
}

generate_work_order() {
  python3 - "$PATCH_FILE" "$WO_FILE" "$WO_ID" <<'PY'
import json, sys, yaml, pathlib
patch_path = pathlib.Path(sys.argv[1])
wo_path = pathlib.Path(sys.argv[2])
wo_id = sys.argv[3]
patch = yaml.safe_load(patch_path.read_text(encoding="utf-8"))
wo = {
    "id": wo_id,
    "task": {"type": "write", "fallback": "lpe", "summary": "smoke test"},
    "patch": patch,
}
wo_path.write_text(json.dumps(wo), encoding="utf-8")
PY
}

generate_patch
generate_work_order

echo "Running LPE worker once for $WO_ID" >&2
LPE_ONESHOT=true "$WORKER"

if ! grep -q "LPE smoke test line" "$TARGET_FILE"; then
  echo "❌ Patch content missing in $TARGET_FILE" >&2
  exit 1
fi

LEDGER_FILE="$LEDGER_DIR/$(date -u +%Y-%m-%d).jsonl"
if [[ ! -f "$LEDGER_FILE" ]] || ! grep -q "$WO_ID" "$LEDGER_FILE"; then
  echo "❌ Ledger entry not found for $WO_ID" >&2
  exit 1
fi

if [[ ! -f "$BASE/bridge/outbox/LPE/${WO_ID}.result.json" ]]; then
  echo "❌ Result JSON missing for $WO_ID" >&2
  exit 1
fi

  wo_status=$(jq -r '.status // empty' "$BASE/bridge/outbox/LPE/${WO_ID}.result.json" 2>/dev/null || echo "")
  if [[ "$wo_status" != "success" ]]; then
    echo "❌ Unexpected status: $wo_status" >&2
    exit 1
  fi

echo "✅ LPE smoke test passed (WO=$WO_ID)"
