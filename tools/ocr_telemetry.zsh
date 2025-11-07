#!/usr/bin/env zsh
# OCR Telemetry Viewer
# Displays OCR SHA256 failure statistics from telemetry log

set -eo pipefail

TELEM_LOG="${HOME}/logs/ocr_telemetry.log"

if [[ ! -f "$TELEM_LOG" ]]; then
  echo "📊 No telemetry data found at $TELEM_LOG"
  exit 0
fi

echo "📊 OCR Telemetry Report (last 50 events)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Show summary statistics
echo ""
echo "Failure Summary:"
while IFS= read -r count type; do
  case "$type" in
    sha_fail) echo "  ❌ Invalid SHA256 format: $count" ;;
    sha_mismatch) echo "  ⚠️  SHA256 mismatch: $count" ;;
    *) echo "  ❓ $type: $count" ;;
  esac
done < <(tail -n 50 "$TELEM_LOG" \
  | awk '{print $3}' \
  | sort \
  | uniq -c \
  | sort -nr) || true

echo ""
echo "Recent Events:"
while IFS= read -r line; do
  timestamp=$(echo "$line" | awk '{print $1}')
  filepath=$(echo "$line" | awk '{print $2}')
  event=$(echo "$line" | awk '{print $3}')

  case "$event" in
    sha_fail) echo "  ❌ [$timestamp] Invalid hash: $(basename "$filepath")" ;;
    sha_mismatch) echo "  ⚠️  [$timestamp] Mismatch: $(basename "$filepath")" ;;
    *) echo "  ❓ [$timestamp] $event: $(basename "$filepath")" ;;
  esac
done < <(tail -n 10 "$TELEM_LOG") || true

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Log location: $TELEM_LOG"
