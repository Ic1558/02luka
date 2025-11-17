#!/usr/bin/env zsh
set -euo pipefail
setopt null_glob

BASE="${LUKA_SOT:-$HOME/02luka}"
WORKER="$BASE/g/tools/lpe_worker.zsh"
TARGET_FILE="$BASE/g/tools/fixtures/lpe_smoke_target.txt"
LEDGER_DIR="$BASE/mls/ledger"
INBOX="$BASE/bridge/inbox/LPE"
OUTBOX="$BASE/bridge/outbox/LPE"
PROCESSED="$BASE/bridge/processed/LPE"

mkdir -p "$INBOX" "$OUTBOX" "$LEDGER_DIR" "${TARGET_FILE:h}"
: > "$TARGET_FILE"

TS="$(date +%Y%m%d_%H%M%S)"
WO_ID="WO-LPE-SMOKE-${TS}"
PATCH_FILE="$INBOX/${WO_ID}.patch.yaml"
WO_FILE="$INBOX/${WO_ID}.yaml"
LEDGER_FILE="$LEDGER_DIR/$(date -u +%Y-%m-%d).jsonl"

rm -f "$INBOX/${WO_ID}"* "$OUTBOX/${WO_ID}"* "$PROCESSED/${WO_ID}"*

SMOKE_LINE="[LPE SMOKE ${TS}]"

cat <<PATCH > "$PATCH_FILE"
ops:
  - path: g/tools/fixtures/lpe_smoke_target.txt
    mode: append
    content: "$SMOKE_LINE"
PATCH

cat <<WO > "$WO_FILE"
id: "$WO_ID"
task:
  type: write
route_hints:
  fallback_order: [lpe, clc]
lpe_patch_file: "$(realpath --relative-to="$BASE" "$PATCH_FILE")"
WO

if [[ ! -x "$WORKER" ]]; then
  echo "LPE worker missing or not executable: $WORKER" >&2
  exit 1
fi

echo "Running LPE worker once for $WO_ID" >&2
LUKA_SOT="$BASE" "$WORKER" --once >/dev/null

if ! grep -q "$SMOKE_LINE" "$TARGET_FILE"; then
  echo "❌ target file missing expected content" >&2
  exit 1
fi

echo "✅ patch applied to $TARGET_FILE" >&2

if ! tail -n 5 "$LEDGER_FILE" | grep -q "$WO_ID"; then
  echo "❌ ledger does not contain entry for $WO_ID" >&2
  exit 1
fi

echo "✅ ledger updated at $LEDGER_FILE" >&2

echo "Smoke test complete" >&2
