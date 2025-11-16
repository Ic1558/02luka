#!/usr/bin/env zsh
set -euo pipefail
OUT="${OUT:-g/telemetry/unified.jsonl}"
mkdir -p "$(dirname "$OUT")"
ts="$(date -u +%FT%TZ)"
agent="${1:-unknown}"
event="${2:-event}"
ok="${3:-true}"
detail="${4:-{}}"
printf '{"ts":"%s","agent":"%s","event":"%s","ok":%s,"detail":%s}\n' "$ts" "$agent" "$event" "$ok" "$detail" >> "$OUT"
