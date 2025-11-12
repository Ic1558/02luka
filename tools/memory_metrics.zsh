#!/usr/bin/env zsh
set -euo pipefail

export LUKA_SOT="${LUKA_SOT:-$HOME/02luka}"
CTX="$LUKA_SOT/shared_memory/context.json"
OUT="$LUKA_SOT/metrics/memory_usage.ndjson"

mkdir -p "$LUKA_SOT/metrics"

ts() { date -Iseconds; }

agents_count=$(jq '.agents|keys|length' "$CTX" 2>/dev/null || echo 0)
saved=$(jq '.token_usage.saved // 0' "$CTX" 2>/dev/null || echo 0)
total=$(jq '.token_usage.total // 0' "$CTX" 2>/dev/null || echo 0)

pct=0
[ "$total" -gt 0 ] && pct=$(( 100 * saved / total ))

printf '{"ts":"%s","agents":%s,"token_total":%s,"token_saved":%s,"saved_pct":%s}\n' \
  "$(ts)" "$agents_count" "$total" "$saved" "$pct" >> "$OUT"

echo "metrics: agents=$agents_count total=$total saved=$saved (${pct}%)"
