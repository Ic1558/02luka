#!/usr/bin/env zsh
set -euo pipefail

BASE="$HOME/02luka"
REPORT_DIR="$BASE/g/reports/system/launchagents_runtime"
LOG_DIR="$BASE/logs"
mkdir -p "$REPORT_DIR" "$LOG_DIR"

STAMP="$(date +%Y%m%d_%H%M%S)"
MD="$REPORT_DIR/RUNTIME_${STAMP}.md"
JSONL="$REPORT_DIR/RUNTIME_${STAMP}.jsonl"

REDIS_PASSWORD="${REDIS_PASSWORD:-gggclukaic}"

log() {
  print "[$(date +%Y-%m-%dT%H:%M:%S)] $*" >> "$LOG_DIR/runtime_state.out.log"
}

safe_redis_numsub() {
  local channel="$1"
  local out
  if ! out="$(redis-cli -a "$REDIS_PASSWORD" PUBSUB NUMSUB "$channel" 2>/dev/null)"; then
    echo "-1"
    return
  fi
  echo "$out" | awk 'NR==2 {print $1+0}'
}

get_launchctl_line() {
  local label="$1"
  launchctl list 2>/dev/null | awk -v lbl="$label" '$3 == lbl {print $0}'
}

status_for_agent() {
  local pid="$1" exit="$2" subs="$3"

  if [[ "$pid" == "-" ]]; then
    if [[ "$exit" != "-" && "$exit" != "0" ]]; then
      echo "error"
    else
      echo "warn"
    fi
  else
    if [[ "$subs" -ge 1 ]]; then
      echo "ok"
    else
      echo "warn"
    fi
  fi
}

print "# LaunchAgent Runtime Validation — $STAMP" > "$MD"
print "" >> "$MD"

for dir in "$BASE/LaunchAgents" "$HOME/Library/LaunchAgents"; do
  [[ -d "$dir" ]] || continue
  for plist in "$dir"/com.02luka.*.plist; do
    [[ -f "$plist" ]] || continue

    label="$(/usr/libexec/PlistBuddy -c 'Print :Label' "$plist" 2>/dev/null || true)"
    [[ -n "$label" ]] || label="$(basename "$plist" .plist)"

    program="$(
      /usr/libexec/PlistBuddy -c 'Print :ProgramArguments:0' "$plist" 2>/dev/null ||
      /usr/libexec/PlistBuddy -c 'Print :Program' "$plist" 2>/dev/null ||
      echo ""
    )"

    lc_line="$(get_launchctl_line "$label")"
    pid="$(print "$lc_line" | awk '{print $1}')"
    exit_code="$(print "$lc_line" | awk '{print $2}')"

    [[ -n "$pid" ]] || pid="-"
    [[ -n "$exit_code" ]] || exit_code="-"

    channel="$(print "$label" | sed 's/^com[.]02luka[.]//')"
    subs="$(safe_redis_numsub "$channel")"
    [[ -n "$subs" ]] || subs=-1

    status="$(status_for_agent "$pid" "$exit_code" "$subs")"

    print "## $label" >> "$MD"
    print "- Program: ${program:-UNKNOWN}" >> "$MD"
    print "- PID: $pid" >> "$MD"
    print "- Exit: $exit_code" >> "$MD"
    print "- Redis channel: $channel" >> "$MD"
    print "- Subscribers: $subs" >> "$MD"
    print "- Status: **$status**" >> "$MD"
    print "" >> "$MD"

    jq -nc \
      --arg label "$label" \
      --arg program "$program" \
      --arg pid "$pid" \
      --arg exit "$exit_code" \
      --arg channel "$channel" \
      --arg status "$status" \
      --arg stamp "$STAMP" \
      --argjson subs "$subs" \
      '{label:$label, program:$program, pid:$pid, exit:$exit, channel:$channel, subs:$subs, status:$status, timestamp:$stamp}' \
      >> "$JSONL"

    log "checked label=$label pid=$pid exit=$exit_code subs=$subs status=$status"
  done
done

print "" >> "$MD"
print "Completed at $STAMP" >> "$MD"
