#!/usr/bin/env zsh
set -euo pipefail

# ---------- config ----------
REPO="${REPO:-$HOME/02luka}"
PLIST="$HOME/Library/LaunchAgents/com.02luka.analytics.parquet.plist"
EXPORT_CJS="$REPO/run/parquet_exporter.cjs"
RUN_SH="$REPO/scripts/analytics/run_parquet_exporter.sh"
TEST_SH="$REPO/scripts/analytics/test_parquet_exporter.sh"
LOG_DIR="$REPO/g/logs"
LOG_FILE="$LOG_DIR/parquet_exporter.log"
OUT_DIR="$REPO/g/analytics"
TS="$(date '+%Y-%m-%d_%H-%M-%S')"
REPORT_DIR="$REPO/g/reports/parquet"
REPORT_FILE="$REPORT_DIR/verify_${TS}.md"
MAX_BYTES=$((5*1024*1024))   # 5 MB

mkdir -p "$REPORT_DIR" "$LOG_DIR" "$OUT_DIR"

PASS=()
FAIL=()
INFO=()

say() { print -r -- "$@" ; }
ok()  { say "✅ $1"; PASS+=("$1"); }
no()  { say "❌ $1"; FAIL+=("$1"); }
ii()  { say "ℹ️  $1"; INFO+=("$1"); }

# ---------- helpers ----------
have() { command -v "$1" >/dev/null 2>&1; }

check_loaded() {
  if launchctl list | grep -Fq "com.02luka.analytics.parquet"; then
    ok "LaunchAgent loaded (launchctl list)"
  else
    no "LaunchAgent not listed in launchctl"
  fi
}

check_plist() {
  if plutil -lint "$PLIST" >/dev/null 2>&1; then
    ok "Plist syntax valid (plutil -lint)"
  else
    no "Plist has syntax errors"
  fi
}

check_execs() {
  local miss=0
  [[ -x "$EXPORT_CJS" || -f "$EXPORT_CJS" ]] || { no "Missing exporter: $EXPORT_CJS"; miss=1; }
  [[ -x "$RUN_SH"     || -f "$RUN_SH"     ]] || { no "Missing runner:   $RUN_SH"; miss=1; }
  [[ -x "$TEST_SH"    || -f "$TEST_SH"    ]] || ii "Optional test script missing: $TEST_SH"
  [[ $miss -eq 0 ]] && ok "Exporter & runner present"
}

check_dirs_logs() {
  [[ -d "$OUT_DIR" ]] && ok "Output dir exists: $OUT_DIR" || no "Output dir missing: $OUT_DIR"
  # Log file may not exist until first run; treat as info.
  if [[ -f "$LOG_FILE" ]]; then
    ok "Log file found: $LOG_FILE"
  else
    ii "Log file not found yet (will appear after first run): $LOG_FILE"
  fi
}

maybe_trigger() {
  # --trigger to force one live export now
  if [[ "${1:-}" == "--trigger" ]]; then
    if [[ -f "$RUN_SH" ]]; then
      chmod +x "$RUN_SH" || true
      ii "Triggering exporter via $RUN_SH"
      if "$RUN_SH"; then
        ok "Live export run completed"
      else
        no "Live export run failed"
      fi
    else
      no "Runner script not found; cannot trigger"
    fi
  fi
}

latest_parquet() {
  ls -t "$OUT_DIR"/*.parquet 2>/dev/null | head -n1
}

check_parquet_file() {
  local f; f="$(latest_parquet || true)"
  if [[ -z "$f" ]]; then
    no "No Parquet found in $OUT_DIR (run exporter or use --trigger)"
    return 1
  fi
  ii "Latest parquet: ${f:t}"
  local sz; sz=$(stat -f %z "$f" 2>/dev/null || stat -c %s "$f" 2>/dev/null || echo 0)
  if [[ "$sz" -le "$MAX_BYTES" ]]; then
    ok "File size OK (≤ 5MB): $((sz/1024)) KB"
  else
    no "File size too large: $((sz/1024)) KB (> 5MB)"
  fi
}

check_duckdb() {
  if ! have duckdb; then
    no "DuckDB not found (please install: brew install duckdb)"
    return 1
  fi
  ok "DuckDB available ($(duckdb --version | head -n1))"
}

check_compression_snappy() {
  local f; f="$(latest_parquet || true)"
  [[ -z "$f" ]] && return 0

  # Try a few DuckDB queries across versions to detect compression
  local out=""
  set +e
  out="$(duckdb -c "SELECT DISTINCT compression FROM parquet_metadata('$f');" 2>/dev/null)"
  local rc=$?
  if [[ $rc -ne 0 || -z "$out" ]]; then
    out="$(duckdb -c "SELECT DISTINCT compression FROM parquet_schema('$f');" 2>/dev/null)"
  fi
  if [[ -z "$out" ]]; then
    # Fallback: just ensure file readable
    duckdb -c "SELECT count(*) FROM read_parquet('$f');" >/dev/null 2>&1
    if [[ $? -eq 0 ]]; then
      ii "Compression not detectable on this DuckDB version; file readable OK"
      set -e
      return 0
    else
      no "Unable to read parquet with DuckDB"
      set -e
      return 1
    fi
  fi
  set -e

  if print -r -- "$out" | grep -iq 'snappy'; then
    ok "Compression = snappy (detected by DuckDB)"
  else
    ii "Compression detected: ${${out//\n'/, }#*--- }"
  fi
}

write_report() {
  {
    print "## ✅ Phase 7.8 – Parquet Agent Verification"
    print "**Timestamp:** $(date '+%Y-%m-%d %H:%M:%S')"
    print "**Repo:** $REPO"
    print ""
    print "### Results"
    print "- Pass: ${#PASS[@]}"
    print "- Fail: ${#FAIL[@]}"
    print ""
    print "#### ✅ Passed"
    for x in "${PASS[@]}"; do print "- $x"; done
    print ""
    print "#### ❌ Failed"
    if (( ${#FAIL[@]} )); then for x in "${FAIL[@]}"; do print "- $x"; done
    else print "- (none)"; fi
    print ""
    print "#### ℹ️  Info"
    for x in "${INFO[@]}"; do print "- $x"; done
  } > "$REPORT_FILE"
  say ""
  say "📝 Report written: $REPORT_FILE"
}

main() {
  # Allow optional --trigger to force a run
  maybe_trigger "${1:-}"

  check_loaded
  check_plist
  check_execs
  check_dirs_logs
  check_duckdb || true
  check_parquet_file || true
  # Only attempt compression check if DuckDB present
  if have duckdb; then
    check_compression_snappy || true
  fi

  write_report

  (( ${#FAIL[@]} )) && exit 1 || exit 0
}

main "${@:-}"
