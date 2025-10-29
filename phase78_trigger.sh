#!/usr/bin/env zsh
set -euo pipefail
INBOX="$HOME/02luka/bridge/inbox/CLC"
TRG="$INBOX/TRIGGER_RUN_WO-251029_$(date +%Y%m%d_%H%M%S).token"
REP="$HOME/02luka/g/reports/parquet"

mkdir -p "$INBOX" "$REP"
print -r -- "run WO-251029-PARQUET-EXPORTER" > "$TRG"

echo "⏳ Trigger dropped: $TRG"
# ให้ CLC รับ WO แล้ว deploy/export แรก (มี RunAtLoad)
sleep 8

# รัน verifier (โหมด trigger) แล้วรายงานผลล่าสุด
chmod +x "$HOME/02luka/scripts/analytics/verify_parquet_agent.sh" 2>/dev/null || true
"$HOME/02luka/scripts/analytics/verify_parquet_agent.sh" --trigger || true

LAST=$(ls -t "$REP"/verify_*.md 2>/dev/null | head -1)
if [[ -n "${LAST:-}" ]]; then
  echo "✅ Verification report:"
  tail -n +1 "$LAST" | sed -n '1,120p'
else
  echo "⚠️ No verification report yet (CLC อาจยังประมวลผลอยู่)."
fi
