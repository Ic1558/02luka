#!/usr/bin/env zsh
set -euo pipefail
ROOT="$HOME/02luka"
REPORTS="$ROOT/g/reports"
ARCHIVE="$REPORTS/archive"
LOG="$REPORTS/_rotate_reports.log"
KEEP_HOURS=${KEEP_HOURS:-24}
DRYRUN=${DRYRUN:-0}
mkdir -p "$ARCHIVE"; touch "$LOG"
STAMP_NOW="$(date '+%Y-%m-%d %H:%M:%S')"
print "[$STAMP_NOW] rotate:start keep=${KEEP_HOURS}h dryrun=${DRYRUN}" | tee -a "$LOG"
typeset -a PATTERNS=(
  'correlation_*' 'OPS_ATOMIC_*'
  'query_perf_daily_*.json' 'query_perf_daily_*.csv'
  'query_perf_weekly_*.json' 'query_perf_weekly_*.csv'
  'optimization_summary_*.txt' 'index_advisor_report.json'
)
tmpfile="$(mktemp)"
for p in "${PATTERNS[@]}"; do
  find "$REPORTS" -maxdepth 1 -type f -name "$p" -mmin +$((KEEP_HOURS*60)) >> "$tmpfile" || true
done
sort -u "$tmpfile" -o "$tmpfile"
TOTAL=$(wc -l < "$tmpfile" | tr -d ' ')
print "[$STAMP_NOW] rotate:candidates total=$TOTAL" | tee -a "$LOG"
if [[ "$TOTAL" -eq 0 ]]; then
  print "[$STAMP_NOW] rotate:done (nothing) " | tee -a "$LOG"
  rm -f "$tmpfile"; exit 0
fi
STAMP="$(date '+%Y%m%d_%H%M%S')"
BUNDLE="$ARCHIVE/reports_$STAMP.tar.gz"
if [[ "$DRYRUN" = "1" ]]; then
  print "Would archive to: $BUNDLE" | tee -a "$LOG"
  cat "$tmpfile" | tee -a "$LOG"
else
  tar -czf "$BUNDLE" -T "$tmpfile"
  tar -tzf "$BUNDLE" >/dev/null
  while IFS= read -r f; do rm -f "$f"; done < "$tmpfile"
  print "[$STAMP_NOW] rotate:archived bundle=$(basename "$BUNDLE") count=$TOTAL size=$(du -h "$BUNDLE" | awk '{print $1}')" | tee -a "$LOG"
fi
rm -f "$tmpfile"
print "[$STAMP_NOW] rotate:done" | tee -a "$LOG"
