#!/usr/bin/env zsh
# verify_wo_promise.zsh - Verify WO promises in MLS and check if WO files exist
# Usage: verify_wo_promise.zsh [--check-mls] [--check-files]
# Returns: 0 = no promises found, 1 = promises found but no WO files, 2 = error

set -euo pipefail

BASE="${LUKA_SOT:-/Users/icmini/02luka}"
MLS_LEDGER="${BASE}/g/knowledge/mls_lessons.jsonl"
MLS_LEDGER_DIR="${BASE}/g/knowledge/mls/ledger"
WO_INBOX="${BASE}/bridge/inbox/ENTRY"
CHECK_MLS=false
CHECK_FILES=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check-mls)
      CHECK_MLS=true
      shift
      ;;
    --check-files)
      CHECK_FILES=true
      shift
      ;;
    *)
      echo "Usage: $0 [--check-mls] [--check-files]" >&2
      exit 2
      ;;
  esac
done

# Default: check both
if [[ "$CHECK_MLS" == "false" ]] && [[ "$CHECK_FILES" == "false" ]]; then
  CHECK_MLS=true
  CHECK_FILES=true
fi

PROMISES_FOUND=0
WO_FILES_FOUND=0

# Check MLS for WO promises
if [[ "$CHECK_MLS" == "true" ]]; then
  echo "🔍 Checking MLS for WO promises..."
  
  # Check main MLS lessons file
  if [[ -f "$MLS_LEDGER" ]]; then
    if grep -qiE "(create.*wo|wo.*will.*be|will.*create.*wo|promise.*wo)" "$MLS_LEDGER" 2>/dev/null; then
      echo "⚠️  Found WO promises in MLS lessons"
      PROMISES_FOUND=1
    fi
  fi
  
  # Check MLS ledger directory (daily files)
  if [[ -d "$MLS_LEDGER_DIR" ]]; then
    for ledger_file in "$MLS_LEDGER_DIR"/*.jsonl(.N); do
      if grep -qiE "(create.*wo|wo.*will.*be|will.*create.*wo|promise.*wo)" "$ledger_file" 2>/dev/null; then
        echo "⚠️  Found WO promises in $(basename "$ledger_file")"
        PROMISES_FOUND=1
      fi
    done
  fi
fi

# Check for WO files in inbox
if [[ "$CHECK_FILES" == "true" ]]; then
  echo "🔍 Checking WO inbox for files..."
  
  if [[ -d "$WO_INBOX" ]]; then
    WO_COUNT=$(find "$WO_INBOX" -type f \( -name "WO-*.yaml" -o -name "WO-*.yml" -o -name "WO-*.json" \) 2>/dev/null | wc -l | tr -d ' ')
    if (( WO_COUNT > 0 )); then
      echo "✅ Found ${WO_COUNT} WO file(s) in inbox"
      WO_FILES_FOUND=1
    else
      echo "⚠️  No WO files found in inbox"
    fi
  else
    echo "⚠️  WO inbox directory not found: $WO_INBOX"
  fi
fi

# Summary
if (( PROMISES_FOUND > 0 )) && (( WO_FILES_FOUND == 0 )); then
  echo ""
  echo "❌ MISMATCH: WO promises found but no WO files created!"
  echo "📋 Action: Create WO files immediately or remove promises from MLS"
  exit 1
elif (( PROMISES_FOUND > 0 )) && (( WO_FILES_FOUND > 0 )); then
  echo ""
  echo "✅ WO promises match WO files"
  exit 0
else
  echo ""
  echo "✅ No WO promises found (or promises match files)"
  exit 0
fi
