#!/usr/bin/env zsh
# OCR Telemetry Viewer
# Displays recent SHA256 validation failures and statistics

set -euo pipefail

ROOT="$HOME/02luka"
TELEM_LOG="$ROOT/g/logs/ocr_telemetry.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_header() {
  echo ""
  echo "═══════════════════════════════════════════════════════════"
  echo "  📊 OCR SHA256 Telemetry Dashboard"
  echo "═══════════════════════════════════════════════════════════"
  echo ""
}

print_summary() {
  if [[ ! -f "$TELEM_LOG" ]]; then
    echo "${YELLOW}⚠️  No telemetry log found at: $TELEM_LOG${NC}"
    echo "   Log will be created when first failure occurs."
    return 0
  fi

  local total_entries=$(wc -l < "$TELEM_LOG")
  echo "📝 Total telemetry entries: ${total_entries}"
  echo ""
}

print_failure_stats() {
  if [[ ! -f "$TELEM_LOG" ]] || [[ ! -s "$TELEM_LOG" ]]; then
    return 0
  fi

  echo "🔍 Failure Statistics (last 50 entries):"
  echo "─────────────────────────────────────────"

  tail -n 50 "$TELEM_LOG" | awk '{print $3}' | sort | uniq -c | sort -nr | while read count type; do
    case "$type" in
      sha_fail)
        echo "  ${RED}❌ SHA256 validation failures:${NC} $count"
        ;;
      sha_mismatch)
        echo "  ${RED}⚠️  Hash mismatches:${NC} $count"
        ;;
      *)
        echo "  ℹ️  $type: $count"
        ;;
    esac
  done

  echo ""
}

print_recent_failures() {
  if [[ ! -f "$TELEM_LOG" ]] || [[ ! -s "$TELEM_LOG" ]]; then
    return 0
  fi

  echo "📋 Recent Failures (last 10):"
  echo "─────────────────────────────────────────"

  tail -n 10 "$TELEM_LOG" | while read timestamp file failure_type extra; do
    local short_file=$(basename "$file")
    case "$failure_type" in
      sha_fail)
        echo "  ${RED}❌${NC} $(date -d "$timestamp" '+%H:%M:%S' 2>/dev/null || echo "$timestamp") - ${short_file} - Invalid hash (len=${extra:-?})"
        ;;
      sha_mismatch)
        echo "  ${YELLOW}⚠️${NC}  $(date -d "$timestamp" '+%H:%M:%S' 2>/dev/null || echo "$timestamp") - ${short_file} - Hash mismatch"
        ;;
      *)
        echo "  ℹ️  $(date -d "$timestamp" '+%H:%M:%S' 2>/dev/null || echo "$timestamp") - ${short_file} - $failure_type"
        ;;
    esac
  done

  echo ""
}

print_health_status() {
  if [[ ! -f "$TELEM_LOG" ]] || [[ ! -s "$TELEM_LOG" ]]; then
    echo "${GREEN}✅ System Status: HEALTHY (no failures recorded)${NC}"
    return 0
  fi

  local recent_failures=$(tail -n 10 "$TELEM_LOG" | wc -l)

  if [[ $recent_failures -eq 0 ]]; then
    echo "${GREEN}✅ System Status: HEALTHY${NC}"
  elif [[ $recent_failures -lt 5 ]]; then
    echo "${YELLOW}⚠️  System Status: WARNING (${recent_failures} recent failures)${NC}"
  else
    echo "${RED}❌ System Status: CRITICAL (${recent_failures} recent failures)${NC}"
  fi

  echo ""
}

main() {
  print_header
  print_summary
  print_health_status
  print_failure_stats
  print_recent_failures

  echo "═══════════════════════════════════════════════════════════"
  echo ""
}

main "$@"
