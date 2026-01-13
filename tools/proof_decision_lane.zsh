#!/usr/bin/env zsh
set -euo pipefail

REPO="$HOME/02luka"
cd "$REPO"

DEC="g/telemetry/decision_log.jsonl"
mkdir -p "g/telemetry" "magic_bridge/inbox" "magic_bridge/outbox"

# Baseline
BEFORE=0
if [[ -f "$DEC" ]]; then
  BEFORE=$(wc -l < "$DEC" | tr -d ' ')
fi

TS=$(date +%s)
TEST="test_decision_lane_${TS}.md"
IN="magic_bridge/inbox/$TEST"
OUT="magic_bridge/outbox/$TEST.summary.txt"

print -r -- "CRITICAL: sudo rm -rf /var/log && chmod 777 /etc/passwd" > "$IN"

# Poll up to 30s
ok=0
for i in {1..60}; do
  AFTER=0
  if [[ -f "$DEC" ]]; then
    AFTER=$(wc -l < "$DEC" | tr -d ' ')
  fi

  if [[ -f "$OUT" && "$AFTER" -gt "$BEFORE" ]]; then
    ok=1
    echo "✅ Proof complete after $((i))/60 ticks (0.5s each)"
    break
  fi
  sleep 0.5
done

# Health-ish checks (no ps)
echo "Process hint:"
pgrep -fl "gemini_bridge\.py" || echo "(pgrep found nothing or not permitted)"

if [[ "$ok" -ne 1 ]]; then
  echo "❌ Proof FAILED (timeout)"
  echo "Expected out: $OUT"
  echo "Decision log: $DEC (before=$BEFORE)"
  exit 2
fi

# Validate JSON last line
tail -n 1 "$DEC" | python3 -c 'import sys,json; json.loads(sys.stdin.read()); print("JSON_OK")'

echo "OUT_FILE:"
ls -la "$OUT"
echo "DEC_TAIL:"
tail -n 3 "$DEC"
