#!/usr/bin/env bash
# Orchestrates the end-to-end ops atomic flow:
#   Phase 1 – Tests (smoke)
#   Phase 2 – Verification (API health)
#   Phase 3 – Notify Prep (summary snapshot)
#   Phase 4 – Report Generation
#   Phase 5 – Discord Notifications

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO_ROOT

# Capture start time for telemetry (milliseconds since epoch)
START_TIME=$(($(date +%s) * 1000))

PASS=0
WARN=0
FAIL=0
RUN_STAMP=""
LATEST_REPORT_PATH=""
LATEST_REPORT_FILE=""
SUMMARY_JSON=""

PHASE_NAMES=()
PHASE_STATUS=()
PHASE_OUTPUTS=()

# Utilities -----------------------------------------------------------------

increment_counter() {
  case "$1" in
    PASS) PASS=$((PASS + 1)) ;;
    WARN) WARN=$((WARN + 1)) ;;
    FAIL) FAIL=$((FAIL + 1)) ;;
  esac
}

determine_overall_status() {
  if (( FAIL > 0 )); then
    echo "fail"
  elif (( WARN > 0 )); then
    echo "warn"
  else
    echo "pass"
  fi
}

trim_output_for_report() {
  local text="$1"
  local limit=${2:-2000}
  local length=${#text}
  if (( length <= limit )); then
    printf '%s\n' "$text"
  else
    local truncated="${text:0:limit}"
    printf '%s\n... (truncated %d chars)\n' "$truncated" $((length - limit))
  fi
}

add_phase_result() {
  PHASE_NAMES+=("$1")
  PHASE_STATUS+=("$2")
  PHASE_OUTPUTS+=("$3")
}

run_phase() {
  local name="$1"
  local failure_mode="${2:-fail}"
  shift 2

  echo ""
  echo "=== Phase $(( ${#PHASE_NAMES[@]} + 1 )): $name ==="

  set +e
  local output
  output=$("$@" 2>&1)
  local exit_code=$?
  set -e

  local status="PASS"
  if [[ $exit_code -ne 0 ]]; then
    if [[ "$failure_mode" == "warn" ]]; then
      status="WARN"
    else
      status="FAIL"
    fi
  fi

  increment_counter "$status"
  add_phase_result "$name" "$status" "$output"

  printf '%s\n' "$output"
  if [[ $status == "PASS" ]]; then
    echo "Result: PASS"
  elif [[ $status == "WARN" ]]; then
    echo "Result: WARN (exit code $exit_code)"
  else
    echo "Result: FAIL (exit code $exit_code)"
  fi
}

ensure_reports_dir() {
  local dir="$REPO_ROOT/g/reports"
  if [[ ! -d "$dir" ]]; then
    mkdir -p "$dir"
  fi
}

generate_report_file() {
  ensure_reports_dir
  if [[ -z "$RUN_STAMP" ]]; then
    RUN_STAMP="$(date -u +%y%m%d_%H%M%S)"
  fi
  local reports_dir="$REPO_ROOT/g/reports"
  local file="OPS_ATOMIC_${RUN_STAMP}.md"
  local path="$reports_dir/$file"
  local iso_now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local overall="$(determine_overall_status)"

  {
    echo "# OPS Atomic Run — $iso_now"
    echo ""
    echo "| Metric | Count |"
    echo "| ------ | ----- |"
    echo "| PASS | $PASS |"
    echo "| WARN | $WARN |"
    echo "| FAIL | $FAIL |"
    echo ""
    echo "## Overall Status"
    echo ""
    echo "- Status: **${overall^^}**"
    echo "- Host: $(hostname)"
    echo "- Report ID: $file"
    echo "- Working Directory: $REPO_ROOT"
    echo ""
    echo "## Phase Results"

    local total_phases=${#PHASE_NAMES[@]}
    for ((i = 0; i < total_phases; i++)); do
      local idx=$((i + 1))
      echo ""
      echo "### Phase $idx: ${PHASE_NAMES[$i]} — ${PHASE_STATUS[$i]}"
      echo ""
      if [[ -n "${PHASE_OUTPUTS[$i]}" ]]; then
        echo '```'
        trim_output_for_report "${PHASE_OUTPUTS[$i]}" 1800
        echo '```'
      else
        echo "_No output recorded._"
      fi
    done
  } > "$path"

  echo "$file" > "$reports_dir/latest"
  LATEST_REPORT_PATH="$path"
  LATEST_REPORT_FILE="$file"

  set +e
  SUMMARY_JSON=$(node "$REPO_ROOT/agents/reportbot/index.cjs" \
    --counts "$PASS,$WARN,$FAIL" \
    --status "$overall" \
    --latest "$path" \
    --write 2>&1)
  local reportbot_exit=$?
  set -e
  if [[ $reportbot_exit -ne 0 ]]; then
    echo "$SUMMARY_JSON" >&2
    return 1
  fi

  echo "Report saved to $path"
  printf '%s\n' "$SUMMARY_JSON"
  return 0
}

extract_report_link() {
  local summary_path="$REPO_ROOT/g/reports/OPS_SUMMARY.json"
  if [[ ! -f "$summary_path" ]]; then
    return
  fi
  python3 - <<'PY'
import json, os, sys
summary_path = os.environ.get('SUMMARY_PATH')
try:
    with open(summary_path, 'r', encoding='utf-8') as handle:
        data = json.load(handle)
    report = data.get('report') or {}
    link = report.get('link') or ''
    path = report.get('path') or ''
    if link:
        print(link)
    elif path:
        print(path)
except Exception:
    pass
PY
}

# Phase execution ------------------------------------------------------------

export SMOKE_SKIP_DISCORD_NOTIFY=1
run_phase "Smoke Tests" "fail" bash "$REPO_ROOT/run/smoke_api_ui.sh"
unset SMOKE_SKIP_DISCORD_NOTIFY || true

run_phase "API Verification" "warn" bash -c "curl -fsS -m 5 http://127.0.0.1:4000/healthz"

overall_status_so_far="$(determine_overall_status)"
run_phase "Notify Prep" "warn" node "$REPO_ROOT/agents/reportbot/index.cjs" \
  --counts "$PASS,$WARN,$FAIL" \
  --status "$overall_status_so_far" \
  --text --no-api

# Phase 4 handled manually so we can reuse report generation output

echo ""
echo "=== Phase $(( ${#PHASE_NAMES[@]} + 1 )): Report Generation ==="
PHASE_NAMES+=("Report Generation")
PHASE_STATUS+=("PASS")
PHASE_OUTPUTS+=("")
increment_counter "PASS"

set +e
phase4_output=$(generate_report_file 2>&1)
phase4_exit=$?
set -e

if [[ $phase4_exit -ne 0 ]]; then
  PASS=$((PASS - 1))
  WARN=$((WARN + 1))
  PHASE_STATUS[-1]="WARN"
else
  PHASE_STATUS[-1]="PASS"
fi
PHASE_OUTPUTS[-1]="$phase4_output"
printf '%s\n' "$phase4_output"
echo "Result: ${PHASE_STATUS[-1]}"

# Phase 5 – Discord Notifications ------------------------------------------

overall_status_before_notify="$(determine_overall_status)"
counts_text="PASS=$PASS WARN=$WARN FAIL=$FAIL"
phase_detail_lines=""
for ((i = 0; i < ${#PHASE_NAMES[@]}; i++)); do
  phase_detail_lines+="• ${PHASE_NAMES[$i]} — ${PHASE_STATUS[$i]}"
  if (( i < ${#PHASE_NAMES[@]} - 1 )); then
    phase_detail_lines+=$'\n'
  fi
done

report_link=""
if link=$(SUMMARY_PATH="$REPO_ROOT/g/reports/OPS_SUMMARY.json" extract_report_link); then
  report_link="$link"
fi

set +e
discord_output=$("$REPO_ROOT/scripts/discord_ops_notify.sh" \
  --status "$overall_status_before_notify" \
  --summary "$counts_text" \
  --details "$phase_detail_lines" \
  --link "$report_link" \
  --title "OPS Atomic $(date -u +%Y-%m-%dT%H:%M:%SZ)" 2>&1)
discord_exit=$?
set -e

echo ""
echo "=== Phase $(( ${#PHASE_NAMES[@]} + 1 )): Discord Notifications ==="
printf '%s\n' "$discord_output"

discord_result=$(echo "$discord_output" | awk -F= '/DISCORD_RESULT=/{print $2}' | tail -n1)
if [[ -z "$discord_result" ]]; then
  discord_result="WARN"
fi

PHASE_NAMES+=("Discord Notifications")
PHASE_STATUS+=("$discord_result")
PHASE_OUTPUTS+=("$discord_output")
if [[ "$discord_result" == "PASS" ]]; then
  increment_counter "PASS"
elif [[ "$discord_result" == "WARN" ]]; then
  increment_counter "WARN"
fi

overall_final_status="$(determine_overall_status)"

# Refresh report to include Discord phase ----------------------------------
set +e
phase5_update=$(generate_report_file 2>&1)
phase5_exit=$?
set -e
if [[ -n "$phase5_update" ]]; then
  printf '%s\n' "$phase5_update"
fi
if [[ $phase5_exit -ne 0 ]]; then
  echo "Report refresh after Discord phase encountered warnings." >&2
fi

echo ""
echo "=== Run Complete ==="
echo "Overall status: ${overall_final_status^^}"
echo "Totals: PASS=$PASS WARN=$WARN FAIL=$FAIL"
if [[ -n "$LATEST_REPORT_PATH" ]]; then
  echo "Latest report: $LATEST_REPORT_PATH"
fi

# Record telemetry
END_TIME=$(($(date +%s) * 1000))
DURATION=$((END_TIME - START_TIME))

if command -v node >/dev/null 2>&1; then
  node "$REPO_ROOT/boss-api/telemetry.cjs" \
    --task ops_atomic \
    --pass "$PASS" \
    --warn "$WARN" \
    --fail "$FAIL" \
    --duration "$DURATION" >/dev/null 2>&1 || true
fi

# Record in vector memory (successful runs only)
if [[ "$overall_final_status" == "pass" ]] && command -v node >/dev/null 2>&1; then
  memory_text="OPS Atomic run completed successfully. Phases: ${PHASE_NAMES[*]}. Results: PASS=$PASS WARN=$WARN FAIL=$FAIL. Duration: ${DURATION}ms."
  node "$REPO_ROOT/memory/index.cjs" --remember plan "$memory_text" >/dev/null 2>&1 || true
fi

# Exit with appropriate status
if [[ "$overall_final_status" == "fail" ]]; then
  exit 1
elif [[ "$overall_final_status" == "warn" ]]; then
  exit 0  # Warnings don't fail the build
else
  exit 0
fi
