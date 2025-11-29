#!/usr/bin/env zsh
set -euo pipefail

ledger_path="g/bridge/LIAM/ledger.jsonl"
archive_dir="g/bridge/LIAM/archive"
dlq_dir="g/bridge/LIAM/dead_letter"
report_path="g/reports/system/wo_dashboard_report.md"

typeset -A counters=(
  [validated]=0
  [schema_failed]=0
  [interpreter_started]=0
  [dispatch]=0
  [dlq]=0
  [timeout]=0
)

ledger_status="No ledger data found"
ledger_available=false
recent_events=()
archive_count=0
dlq_count=0
recent_dlqs=()

usage() {
  cat <<'USAGE'
Usage: g/tools/wo_dashboard_minimal.zsh [options]

Generate a minimal Auto WO Bridge dashboard report at g/reports/system/wo_dashboard_report.md.

Options:
  -h, --help    Show this help message.
USAGE
}

extract_json_field() {
  local line="$1"
  local key="$2"
  print -r -- "$line" | awk -v key="$key" '
    BEGIN {
      pattern = "\"" key "\"[[:space:]]*:[[:space:]]*\"([^\"]+)\""
    }
    match($0, pattern, m) { print m[1] }
  '
}

parse_ledger() {
  if [[ ! -f "$ledger_path" || ! -s "$ledger_path" ]]; then
    ledger_status="No ledger data found"
    ledger_available=false
    return
  fi

  ledger_status="Ledger data available"
  ledger_available=true

  while IFS= read -r line; do
    local event
    event=$(extract_json_field "$line" "event_type")
    if [[ -n "$event" ]]; then
      local current=${counters[$event]-0}
      counters[$event]=$(( current + 1 ))
    fi
  done < "$ledger_path"

  IFS=$'\n' recent_events=($(tail -n 10 "$ledger_path"))
}

get_dlq_reason() {
  local target="$1"
  [[ -f "$ledger_path" ]] || { print -r -- "Not available"; return; }

  local reason
  reason=$(awk -v target="$target" '
    index($0, target) > 0 {
      if (match($0, /"reason"[[:space:]]*:[[:space:]]*"([^"]+)"/, m)) {
        found = m[1]
      } else if (match($0, /"error"[[:space:]]*:[[:space:]]*"([^"]+)"/, m)) {
        found = m[1]
      }
    }
    END {
      if (length(found)) print found;
    }
  ' "$ledger_path")

  if [[ -z "$reason" ]]; then
    print -r -- "Reason not found in ledger"
  else
    print -r -- "$reason"
  fi
}

scan_archive_dlq() {
  if [[ -d "$archive_dir" ]]; then
    archive_count=$(find "$archive_dir" -type f | wc -l | awk '{print $1}')
  else
    archive_count=0
  fi

  if [[ -d "$dlq_dir" ]]; then
    dlq_count=$(find "$dlq_dir" -type f | wc -l | awk '{print $1}')
    local dlq_files
    dlq_files=($(ls -1t "$dlq_dir" 2>/dev/null | head -n 5))
    recent_dlqs=()
    for file in "${dlq_files[@]}"; do
      recent_dlqs+=("$file")
    done
  else
    dlq_count=0
    recent_dlqs=()
  fi
}

format_recent_events() {
  if ! $ledger_available; then
    print -- "- No ledger data available"
    return
  fi

  for line in "${recent_events[@]}"; do
    local ts event summary
    ts=$(extract_json_field "$line" "timestamp")
    [[ -z "$ts" ]] && ts=$(extract_json_field "$line" "ts")
    [[ -z "$ts" ]] && ts=$(extract_json_field "$line" "created_at")
    event=$(extract_json_field "$line" "event_type")
    summary=$(extract_json_field "$line" "summary")
    [[ -z "$summary" ]] && summary=$(extract_json_field "$line" "reason")
    [[ -z "$summary" ]] && summary=$(extract_json_field "$line" "message")

    local formatted
    formatted="${ts:-N/A} | ${event:-unknown}"
    [[ -n "$summary" ]] && formatted+=" – $summary"
    print -- "- $formatted"
  done
}

render_report() {
  local generated_at
  generated_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  cat <<EOF > "$report_path"
# Auto WO Bridge – WO Dashboard (Minimal v1)
Generated at: $generated_at

## Summary Counters
- Ledger status: $ledger_status
- Archived WOs: $archive_count
- Dead letters: $dlq_count

| Event | Count |
| --- | ---: |
| validated | ${counters[validated]:-0} |
| schema_failed | ${counters[schema_failed]:-0} |
| interpreter_started | ${counters[interpreter_started]:-0} |
| dispatch | ${counters[dispatch]:-0} |
| dlq | ${counters[dlq]:-0} |
| timeout | ${counters[timeout]:-0} |

## Recent Events
EOF

  format_recent_events >> "$report_path"

  cat <<EOF >> "$report_path"

## Recent Dead Letters
EOF

  if [[ ${#recent_dlqs[@]} -eq 0 ]]; then
    echo "- No dead letters found" >> "$report_path"
  else
    for file in "${recent_dlqs[@]}"; do
      local reason
      reason=$(get_dlq_reason "$file")
      print -- "- $file – $reason" >> "$report_path"
    done
  fi
}

main() {
  if [[ ${#@} -gt 0 ]]; then
    case "$1" in
      -h|--help)
        usage
        exit 0
        ;;
      *)
        print "Unknown option: $1" >&2
        usage
        exit 1
        ;;
    esac
  fi

  parse_ledger
  scan_archive_dlq
  render_report
}

main "$@"
