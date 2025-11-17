#!/usr/bin/env zsh

# LaunchAgent runtime validator
#
# Scans LaunchAgent plists under the user and repo LaunchAgent directories,
# captures launchctl + Redis runtime data, and writes both Markdown and JSONL
# reports alongside an operator log.

set -u

SCRIPT_DIR="$(cd -- "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
DEFAULT_REPORT_DIR="$REPO_ROOT/reports/system/launchagents_runtime"
LOG_FILE="$HOME/02luka/logs/runtime_state.out.log"

usage() {
  cat <<'USAGE'
Usage: validate_runtime_state.zsh [--output-dir DIR]

Options:
  --output-dir DIR   Override the default report directory
                     (defaults to g/reports/system/launchagents_runtime).

The script is safe to run repeatedly. It tolerates missing runtime
dependencies (launchctl, redis-cli) and records any gaps as warnings.
USAGE
}

OUTPUT_DIR="$DEFAULT_REPORT_DIR"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-dir)
      [[ $# -lt 2 ]] && { echo "Missing value for --output-dir" >&2; exit 1; }
      OUTPUT_DIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

mkdir -p "$OUTPUT_DIR" "$HOME/02luka/logs"

log() {
  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S%z')"
  echo "[$ts] $1" | tee -a "$LOG_FILE"
}

json_escape() {
  local s="$1"
  s=${s//\\/\\\\}
  s=${s//"/\\"}
  s=${s//$'\n'/\\n}
  echo "$s"
}

collect_plists() {
  local -a dirs plists
  dirs=("$HOME/02luka/LaunchAgents" "$HOME/Library/LaunchAgents")
  plists=()

  for dir in "$dirs[@]"; do
    if [[ -d "$dir" ]]; then
      while IFS= read -r plist; do
        plists+=("$plist")
      done < <(find "$dir" -maxdepth 1 -type f -name 'com.02luka.*.plist' | sort)
    else
      log "WARN: Missing LaunchAgents directory: $dir"
    fi
  done

  echo ${plists[@]:-}
}

extract_program_path() {
  local plist="$1" value

  if command -v plutil >/dev/null 2>&1; then
    value=$(plutil -extract Program raw "$plist" 2>/dev/null)
    if [[ -z "$value" ]]; then
      value=$(plutil -extract ProgramArguments.0 raw "$plist" 2>/dev/null)
    fi
  fi

  if [[ -z "${value:-}" ]]; then
    value=$(grep -A1 '<key>Program</key>' "$plist" 2>/dev/null | tail -n1 | sed -E 's/.*<string>(.*)<\/string>.*/\1/')
  fi

  if [[ -z "${value:-}" ]]; then
    value="(unknown)"
  fi

  echo "$value"
}

collect_launchctl_state() {
  local label="$1" pid="-" exit_code="-" state="unavailable"

  if command -v launchctl >/dev/null 2>&1; then
    state="not_loaded"
    local line
    line=$(launchctl list 2>/dev/null | awk -v target="$label" '$3==target {print $1" "$2}')
    if [[ -n "${line:-}" ]]; then
      pid="${line%% *}"
      exit_code="${line##* }"
      state="loaded"
    fi
  fi

  echo "$pid|$exit_code|$state"
}

collect_redis_subs() {
  local channel="$1" subs="unknown" source="unavailable"

  if command -v redis-cli >/dev/null 2>&1; then
    source="queried"
    local out
    out=$(redis-cli --raw PUBSUB NUMSUB "$channel" 2>/dev/null)
    # --raw returns two lines: channel name and subscriber count
    subs=$(echo "$out" | awk 'NR==2 {print $1}')
    [[ -z "${subs:-}" ]] && subs="0"
  fi

  echo "$subs|$source"
}

classify_status() {
  local pid="$1" exit_code="$2" launchctl_state="$3" subs="$4" program_path="$5"
  local status="ok" reasons=()

  if [[ "$launchctl_state" == "unavailable" ]]; then
    status="warn"
    reasons+=("launchctl unavailable")
  elif [[ "$launchctl_state" == "not_loaded" ]]; then
    status="error"
    reasons+=("not loaded")
  else
    if [[ "$pid" == "-" || -z "$pid" ]]; then
      status="warn"
      reasons+=("no pid")
    fi
    if [[ -n "$exit_code" && "$exit_code" != "0" && "$exit_code" != "-" ]]; then
      status="error"
      reasons+=("exit $exit_code")
    fi
  fi

  if [[ "$subs" == "0" || "$subs" == "unknown" ]]; then
    [[ "$status" == "ok" ]] && status="warn"
    reasons+=("redis subscribers: $subs")
  fi

  if [[ "$program_path" == "(unknown)" ]]; then
    [[ "$status" == "ok" ]] && status="warn"
    reasons+=("program path unknown")
  fi

  echo "$status|${(j:;:)reasons}"
}

write_reports() {
  local report_ts="$1" agents_count="$2" md_body="$3" json_lines="$4"
  local md_path="$OUTPUT_DIR/RUNTIME_${report_ts}.md"
  local json_path="$OUTPUT_DIR/RUNTIME_${report_ts}.jsonl"

  cat > "$md_path" <<EOF_MD
# LaunchAgent Runtime Report
Generated: $(date '+%Y-%m-%d %H:%M:%S %Z')
Host: $(hostname)
Agents scanned: $agents_count

${md_body}
EOF_MD

  printf "%s" "$json_lines" > "$json_path"

  log "Wrote Markdown report: $md_path"
  log "Wrote JSONL report: $json_path"
}

main() {
  local -a plists markdown_sections
  local json_accum="" status_counts ok=0 warn=0 error=0

  log "Starting LaunchAgent runtime validation"

  plists=($(collect_plists))
  if [[ ${#plists[@]} -eq 0 ]]; then
    log "WARN: No LaunchAgent plists found under ~/02luka/LaunchAgents or ~/Library/LaunchAgents"
  fi

  for plist in "$plists[@]"; do
    local label="${plist:t:r}"
    local channel="${label#com.02luka.}"
    local program_path launchctl_raw redis_raw pid exit_code lc_state subs redis_state status reasons status_reasons

    program_path=$(extract_program_path "$plist")

    launchctl_raw=$(collect_launchctl_state "$label")
    pid="${launchctl_raw%%|*}"
    exit_code="${launchctl_raw#*|}"
    lc_state="${exit_code#*|}"
    exit_code="${exit_code%%|*}"

    redis_raw=$(collect_redis_subs "$channel")
    subs="${redis_raw%%|*}"
    redis_state="${redis_raw#*|}"

    status_reasons=$(classify_status "$pid" "$exit_code" "$lc_state" "$subs" "$program_path")
    status="${status_reasons%%|*}"
    reasons="${status_reasons#*|}"

    case "$status" in
      ok) ((ok++)) ;;
      warn) ((warn++)) ;;
      error) ((error++)) ;;
    esac

    markdown_sections+=("### $label\n- **Plist:** $plist\n- **Program:** $program_path\n- **Status:** ${status:u} (${reasons:-none})\n- **launchctl:** state=$lc_state pid=$pid exit=$exit_code\n- **Redis:** channel=$channel subscribers=$subs (source: $redis_state)\n")

    local json_reasons reason_item
    local -a reason_list reason_fragments
    reason_list=(${(s:;:)reasons})
    reason_fragments=()
    for reason_item in "${reason_list[@]}"; do
      [[ -z "$reason_item" ]] && continue
      reason_fragments+=("\"$(json_escape "$reason_item")\"")
    done
    if [[ ${#reason_fragments[@]} -gt 0 ]]; then
      json_reasons="[${(j:, :)reason_fragments}]"
    else
      json_reasons="[]"
    fi

    json_accum+="{\"label\":\"$(json_escape "$label")\",\"plist\":\"$(json_escape "$plist")\",\"program\":\"$(json_escape "$program_path")\",\"status\":\"$status\",\"reasons\":${json_reasons},\"launchctl\":{\"state\":\"$lc_state\",\"pid\":\"$pid\",\"exit_code\":\"$exit_code\"},\"redis\":{\"channel\":\"$(json_escape "$channel")\",\"subscribers\":\"$subs\",\"state\":\"$redis_state\"}}
"
  done

  local summary="Summary: ok=$ok warn=$warn error=$error"
  markdown_sections=(${markdown_sections[@]} "${summary}")

  local report_ts
  report_ts=$(date '+%Y%m%d_%H%M%S')
  write_reports "$report_ts" "${#plists[@]}" "$(${(F)markdown_sections})" "$json_accum"

  log "$summary"
  log "Validation complete"
}

main "$@"
