#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "$0")" && pwd)
BASE="${SCRIPT_DIR%/tools}"
LEDGER_DIR="$BASE/mls/ledger"
LESSONS_FILE="$BASE/g/knowledge/mls_lessons.jsonl"

mkdir -p "$LEDGER_DIR"

usage() {
  echo "Usage: $0 (--file PATCH.yaml | --stdin)" >&2
  exit 1
}

PATCH_SOURCE=""
PATCH_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file)
      PATCH_SOURCE="file"
      PATCH_FILE="$2"
      shift 2
      ;;
    --stdin)
      PATCH_SOURCE="stdin"
      shift 1
      ;;
    *)
      usage
      ;;
  esac
done

[[ -n "$PATCH_SOURCE" ]] || usage

TMP_PATCH=$(mktemp)
if [[ "$PATCH_SOURCE" == "file" ]]; then
  if [[ ! -f "$PATCH_FILE" ]]; then
    echo "Patch file not found: $PATCH_FILE" >&2
    exit 1
  fi
  cp "$PATCH_FILE" "$TMP_PATCH"
else
  cat > "$TMP_PATCH"
fi

python3 "$BASE/tools/lpe_sip_apply.py" "$TMP_PATCH"

STAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
LEDGER_FILE="$LEDGER_DIR/$(date -u +%Y-%m-%d).jsonl"

python3 - "$TMP_PATCH" "$LEDGER_FILE" "$STAMP" "$LESSONS_FILE" <<'PY'
import json
import sys
import pathlib
import datetime
import yaml

patch_path = pathlib.Path(sys.argv[1]).resolve()
ledger_path = pathlib.Path(sys.argv[2]).resolve()
stamp = sys.argv[3]
lessons_path = pathlib.Path(sys.argv[4])

with open(patch_path, "r", encoding="utf-8") as f:
    patch_data = yaml.safe_load(f) or {}

entry = {
    "ts": stamp,
    "source": "LPE",
    "patch": patch_data,
}

ledger_path.parent.mkdir(parents=True, exist_ok=True)
with open(ledger_path, "a", encoding="utf-8") as ledger:
    ledger.write(json.dumps(entry, ensure_ascii=False) + "\n")

# Touch lessons file to ensure it exists for downstream tooling
lessons_path.parent.mkdir(parents=True, exist_ok=True)
lessons_path.touch(exist_ok=True)
PY

echo "[LPE] Patch applied via SIP at $STAMP" >&2
rm -f "$TMP_PATCH"
