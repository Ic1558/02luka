#!/usr/bin/env zsh
# mls_event_verifier.zsh
# Verify MLS events include context-protocol-v3.2 tag
set -euo pipefail

SOT="${SOT:-$HOME/02luka}"
LEDGER_DIR="${LEDGER_DIR:-$SOT/mls/ledger}"
DATE="${1:-$(date -u +%Y-%m-%d)}"
LEDGER_FILE="$LEDGER_DIR/${DATE}.jsonl"

echo "[mls-verify] MLS Event Verifier"
echo "[mls-verify] Date: $DATE"
echo "[mls-verify] Ledger: $LEDGER_FILE"

if [[ ! -f "$LEDGER_FILE" ]]; then
  echo "[mls-verify] ⚠️  Ledger file not found: $LEDGER_FILE"
  exit 0
fi

if [[ ! -s "$LEDGER_FILE" ]]; then
  echo "[mls-verify] ⚠️  Ledger file is empty: $LEDGER_FILE"
  exit 0
fi

# Count events with context-protocol-v3.2 tag
COUNT=0
if grep -q "context-protocol-v3.2" "$LEDGER_FILE" 2>/dev/null; then
  COUNT=$(grep -c "context-protocol-v3.2" "$LEDGER_FILE" 2>/dev/null)
  COUNT=${COUNT:-0}
fi

if [[ "$COUNT" -gt 0 ]]; then
  echo "[mls-verify] ✅ Found $COUNT events with context-protocol-v3.2 tag"
  
  # Show sample events
  echo "[mls-verify] Sample events:"
  grep "context-protocol-v3.2" "$LEDGER_FILE" 2>/dev/null | head -3 | jq -r '.timestamp + " " + .type' 2>/dev/null || grep "context-protocol-v3.2" "$LEDGER_FILE" 2>/dev/null | head -3
else
  echo "[mls-verify] ⚠️  No events with context-protocol-v3.2 tag found"
fi

# Check for bridge-related events
BRIDGE_COUNT=0
if grep -qE "bridge.*context-protocol-v3.2|context-protocol-v3.2.*bridge" "$LEDGER_FILE" 2>/dev/null; then
  BRIDGE_COUNT=$(grep -cE "bridge.*context-protocol-v3.2|context-protocol-v3.2.*bridge" "$LEDGER_FILE" 2>/dev/null)
  BRIDGE_COUNT=${BRIDGE_COUNT:-0}
fi
if [[ "$BRIDGE_COUNT" -gt 0 ]]; then
  echo "[mls-verify] ✅ Found $BRIDGE_COUNT bridge events with Protocol v3.2 tag"
fi

exit 0
