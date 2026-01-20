#!/usr/bin/env zsh
set -euo pipefail

TOKEN="${1:-}"
OUTPUT_DIR="${2:-}"
TARGET_ROOT="${3:-}"

if [[ -z "$TOKEN" || -z "$OUTPUT_DIR" || -z "$TARGET_ROOT" ]]; then
  echo "usage: pa_apply.zsh <approve_token_or_path> /tmp/openwork_runs/<run_id> <target_root>"
  exit 1
fi

result=$(python3 g/tools/pa_apply.py --approve-token "$TOKEN" --output-dir "$OUTPUT_DIR" --target-root "$TARGET_ROOT")
echo "$result" | python3 - <<'PY'
import json
import sys

data = json.loads(sys.stdin.read() or "{}")
status = data.get("status")
manifest = data.get("apply_manifest") or ""
print(f"apply:{status} {manifest}".strip())
PY
