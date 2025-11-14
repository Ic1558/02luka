#!/usr/bin/env zsh
# MLS Ledger Monitor - Watches for file disappearance/corruption
# Run this periodically to ensure ledger files remain intact
set -euo pipefail

BASE="$HOME/02luka"
LEDGER_DIR="$BASE/mls/ledger"
LOG_FILE="$BASE/logs/mls_ledger_monitor.log"
TODAY="$(TZ=Asia/Bangkok date +%Y-%m-%d)"
TODAY_FILE="$LEDGER_DIR/${TODAY}.jsonl"

mkdir -p "$(dirname "$LOG_FILE")"

log() {
  echo "[$(date +%Y-%m-%dT%H:%M:%S)] $*" | tee -a "$LOG_FILE"
}

check_file() {
  local file="$1"
  local basename=$(basename "$file")
  
  # Check existence
  if [[ ! -f "$file" ]]; then
    log "❌ MISSING: $basename"
    return 1
  fi
  
  # Check size
  if [[ ! -s "$file" ]]; then
    log "⚠️  EMPTY: $basename"
    return 1
  fi
  
  # Check if valid JSONL
  local invalid_lines=0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    if ! echo "$line" | jq -e . >/dev/null 2>&1; then
      ((invalid_lines++))
    fi
  done < "$file"
  
  if [[ $invalid_lines -gt 0 ]]; then
    log "⚠️  CORRUPTED: $basename ($invalid_lines invalid lines)"
    return 1
  fi
  
  log "✅ OK: $basename"
  return 0
}

# Check today's file (critical)
if ! check_file "$TODAY_FILE"; then
  log "🚨 CRITICAL: Today's ledger file has issues!"
  log "   Attempting auto-recovery..."
  
  # Try to restore from git
  if "$BASE/tools/mls_ledger_protect.zsh" restore "$TODAY_FILE" >> "$LOG_FILE" 2>&1; then
    log "✅ Auto-recovery successful"
  else
    log "❌ Auto-recovery failed - manual intervention needed"
    # Send alert (you can customize this)
    echo "🚨 MLS Ledger Critical Issue: $TODAY_FILE" >&2
  fi
fi

# Check recent files (last 7 days)
for i in {0..6}; do
  date=$(date -v-${i}d +%Y-%m-%d 2>/dev/null || date -d "-${i} days" +%Y-%m-%d 2>/dev/null)
  file="$LEDGER_DIR/${date}.jsonl"
  if [[ -f "$file" ]]; then
    check_file "$file" || true
  fi
done

# Update status summary if needed
if [[ -f "$BASE/tools/mls_status_summary_update.zsh" ]]; then
  "$BASE/tools/mls_status_summary_update.zsh" >> "$LOG_FILE" 2>&1 || true
fi

log "--- Monitor check complete ---"
