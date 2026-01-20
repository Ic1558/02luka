#!/usr/bin/env zsh
set -euo pipefail

INPUT="${1:-}"
OUTPUT_DIR="${2:-}"

if [[ -z "$INPUT" || -z "$OUTPUT_DIR" ]]; then
  echo "usage: pa_dry_run.zsh '<json-or-path>' /tmp/openwork_runs/<run_id>"
  exit 1
fi

result=$(python3 g/tools/pa_intake.py --mode dry_run --input "$INPUT" --output-dir "$OUTPUT_DIR")
echo "$result" | python3 - <<'PY'
import json
import sys

data = json.loads(sys.stdin.read() or "{}")
status = data.get("status")
plan_hash = data.get("plan_hash") or ""
token = data.get("approve_token") or ""
print(f"dry_run:{status} {plan_hash[:12]} {token[:12]}".strip())
PY
