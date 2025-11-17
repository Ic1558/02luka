#!/usr/bin/env zsh
set -euo pipefail

BASE="${HOME}/02luka"

LAUNCHAGENT_DIRS=(
  "${BASE}/LaunchAgents"
  "${HOME}/Library/LaunchAgents"
)

REPORT_DIR="${BASE}/g/reports/system/launchagents"
mkdir -p "${REPORT_DIR}"

TIMESTAMP="$(date +"%Y%m%d_%H%M%S")"
REPORT_MD="${REPORT_DIR}/VALIDATE_${TIMESTAMP}.md"
REPORT_JSON="${REPORT_DIR}/VALIDATE_${TIMESTAMP}.jsonl"

typeset -i TOTAL_OK=0
typeset -i TOTAL_WARN=0
typeset -i TOTAL_ERR=0

log_md() {
  print -- "$1" >> "${REPORT_MD}"
}

log_json() {
  print -- "$1" >> "${REPORT_JSON}"
}

get_plist_value() {
  local plist="$1"
  local key="$2"
  /usr/libexec/PlistBuddy -c "Print :${key}" "$plist" 2>/dev/null || true
}

validate_one_plist() {
  local plist="$1"
  local label program keepalive throttle result msg
  local program_path program_exists="no" program_exec="no"

  label="$(get_plist_value "$plist" "Label")"
  [[ -z "$label" ]] && label="(missing)"

  program="$(get_plist_value "$plist" "Program")"
  if [[ -z "$program" ]]; then
    program="$(get_plist_value "$plist" "ProgramArguments:0")"
  fi

  if [[ -n "$program" ]]; then
    program_path="$program"
    if [[ -f "$program_path" ]]; then
      program_exists="yes"
      if [[ -x "$program_path" ]]; then
        program_exec="yes"
      fi
    fi
  fi

  keepalive="$(get_plist_value "$plist" "KeepAlive")"
  throttle="$(get_plist_value "$plist" "ThrottleInterval")"

  result="OK"
  msg="All checks passed"

  if [[ "$label" == "(missing)" ]]; then
    result="ERROR"
    msg="Missing Label"
  elif [[ -z "$program" ]]; then
    result="ERROR"
    msg="Missing Program/ProgramArguments[0]"
  elif [[ "$program_exists" != "yes" ]]; then
    result="ERROR"
    msg="Program path does not exist: ${program_path:-"(empty)"}"
  elif [[ "$program_exec" != "yes" ]]; then
    result="WARN"
    msg="Program not executable: ${program_path}"
  fi

  case "$result" in
    OK)   TOTAL_OK+=1 ;;
    WARN) TOTAL_WARN+=1 ;;
    ERROR) TOTAL_ERR+=1 ;;
  esac

  log_md "- **${label}** \`$plist\`  
  - Status: **${result}**  
  - Program: \`${program_path:-"(none)"}\`  
  - Exists: ${program_exists}, Executable: ${program_exec}  
  - KeepAlive: \`${keepalive:-"(unset)"}\`, ThrottleInterval: \`${throttle:-"(unset)"}\`  
  - Note: ${msg}  
"

  log_json "$(jq -n --arg label "$label" \
                    --arg plist "$plist" \
                    --arg status "$result" \
                    --arg program "$program_path" \
                    --arg exists "$program_exists" \
                    --arg exec "$program_exec" \
                    --arg keepalive "$keepalive" \
                    --arg throttle "$throttle" \
                    --arg note "$msg" \
    '{label:$label, plist:$plist, status:$status, program:$program,
      program_exists:$exists, program_executable:$exec,
      keepalive:$keepalive, throttle:$throttle, note:$note}')"
}

run_validation() {
  log_md "# LaunchAgent Validation Report"
  log_md ""
  log_md "- Timestamp: \`${TIMESTAMP}\`"
  log_md ""

  local dir plist
  for dir in "${LAUNCHAGENT_DIRS[@]}"; do
    [[ -d "$dir" ]] || continue
    log_md "## Directory: \`$dir\`"
    log_md ""
    for plist in "$dir"/com.02luka.*.plist; do
      [[ -f "$plist" ]] || continue
      validate_one_plist "$plist"
    done
  done

  log_md "---"
  log_md ""
  log_md "## Summary"
  log_md ""
  log_md "- OK: ${TOTAL_OK}"
  log_md "- WARN: ${TOTAL_WARN}"
  log_md "- ERROR: ${TOTAL_ERR}"

  log_json "$(jq -n --arg ts "$TIMESTAMP" \
    --argjson ok "$TOTAL_OK" \
    --argjson warn "$TOTAL_WARN" \
    --argjson err "$TOTAL_ERR" \
    '{timestamp:$ts, summary:{ok:$ok, warn:$warn, error:$err}}')"
}

run_validation
