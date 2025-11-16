#!/usr/bin/env zsh
# 02LUKA WO Executor - Executes Work Order Scripts
# Watches bridge/inbox/LLM for .zsh WO scripts and executes them

set -euo pipefail

# ===== Configuration =====
ROOT="$HOME/02luka"
CFG="$ROOT/config/wo_executor.yaml"
IN_LLM="$ROOT/bridge/inbox/LLM"
ARCHIVE="$ROOT/bridge/archive/WO"
TEL="$ROOT/telemetry"
RUN="$ROOT/run"
STATE_FILE="$RUN/wo_executor_state.json"
MLS_HOOK="$ROOT/tools/mls_auto_capture_hook.zsh"

mkdir -p "$IN_LLM" "$ARCHIVE" "$TEL" "$RUN"

# ===== Logging =====
log() {
  local level="$1"; shift
  local msg="$*"
  local ts=$(date '+%Y-%m-%dT%H:%M:%S%z')
  echo "[$ts] [$level] $msg" | tee -a "$TEL/wo_executor.log"

  if [ -f "$TEL/wo_executor_decisions.jsonl" ] || [ "$level" = "EXECUTION" ]; then
    jq -n --arg ts "$ts" --arg lvl "$level" --arg msg "$msg" \
      '{timestamp: $ts, level: $lvl, message: $msg}' >> "$TEL/wo_executor_decisions.jsonl"
  fi
}

# ===== Load Config (with defaults) =====
if [ -f "$CFG" ]; then
  ENABLED=$(yq -r '.wo_executor.enabled // true' "$CFG" 2>/dev/null || echo "true")
  MAX_WOS=$(yq -r '.wo_executor.max_wos_per_cycle // 3' "$CFG" 2>/dev/null || echo 3)
  TIMEOUT=$(yq -r '.wo_executor.timeout_per_wo_s // 600' "$CFG" 2>/dev/null || echo 600)
  DISK_MIN_GB=$(yq -r '.wo_executor.safety.disk_guard.min_free_gb // 5' "$CFG" 2>/dev/null || echo 5)
  MAX_FAILURES=$(yq -r '.wo_executor.safety.circuit_breaker.max_failures // 3' "$CFG" 2>/dev/null || echo 3)
else
  log WARN "Config not found: $CFG (using defaults)"
  ENABLED="true"
  MAX_WOS=3
  TIMEOUT=600
  DISK_MIN_GB=5
  MAX_FAILURES=3
fi

[ "$ENABLED" = "false" ] && { log INFO "WO Executor disabled in config"; exit 0; }

# ===== Safety Checks =====
check_disk() {
  local free_gb=$(df -g ~ | awk 'NR==2 {print $4}')
  if (( free_gb < DISK_MIN_GB )); then
    log ERROR "Disk space low: ${free_gb}GB free (need ${DISK_MIN_GB}GB)"
    return 1
  fi
  return 0
}

# Circuit breaker check
check_circuit() {
  if [ ! -f "$STATE_FILE" ]; then
    echo '{"failures": 0, "last_failure": null}' > "$STATE_FILE"
    return 0
  fi

  local failures=$(jq -r '.failures // 0' "$STATE_FILE")
  if (( failures >= MAX_FAILURES )); then
    local last_fail=$(jq -r '.last_failure // ""' "$STATE_FILE")
    local now=$(date +%s)
    local last_ts=$(date -j -f '%Y-%m-%dT%H:%M:%S%z' "$last_fail" +%s 2>/dev/null || echo 0)
    local pause_sec=$((60 * 60)) # 60 minutes

    if (( now - last_ts < pause_sec )); then
      log WARN "Circuit breaker OPEN (${failures} failures, paused)"
      return 1
    else
      # Reset after pause period
      echo '{"failures": 0, "last_failure": null}' > "$STATE_FILE"
      log INFO "Circuit breaker RESET"
    fi
  fi
  return 0
}

record_failure() {
  local failures=$(jq -r '.failures // 0' "$STATE_FILE" 2>/dev/null || echo 0)
  failures=$((failures + 1))
  jq -n --arg f "$failures" --arg ts "$(date '+%Y-%m-%dT%H:%M:%S%z')" \
    '{failures: ($f|tonumber), last_failure: $ts}' > "$STATE_FILE"
}

reset_failures() {
  echo '{"failures": 0, "last_failure": null}' > "$STATE_FILE"
}

# ===== WO Execution =====
execute_wo() {
  local wo_file="$1"
  local wo_name=$(basename "$wo_file")
  local log_file="$TEL/wo_execution_${wo_name%.zsh}_$(date +%Y%m%d_%H%M%S).log"

  log INFO "Executing WO: $wo_name"

  # Create execution log
  {
    echo "════════════════════════════════════════════════════════════"
    echo "WO Execution: $wo_name"
    echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "════════════════════════════════════════════════════════════"
    echo ""
  } > "$log_file"

  # Execute with timeout
  local result="success"
  if timeout "$TIMEOUT" zsh "$wo_file" >> "$log_file" 2>&1; then
    log EXECUTION "WO completed successfully: $wo_name"
    result="success"
  else
    local exit_code=$?
    if (( exit_code == 124 )); then
      log ERROR "WO timed out after ${TIMEOUT}s: $wo_name"
      result="timeout"
    else
      log ERROR "WO failed with exit code $exit_code: $wo_name"
      result="failure"
    fi
  fi

  # Append completion
  {
    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo "Completed: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Result: $result"
    echo "════════════════════════════════════════════════════════════"
  } >> "$log_file"

  # Call MLS auto-capture hook
  if [[ -x "$MLS_HOOK" ]]; then
    log INFO "Capturing lesson via MLS hook"
    "$MLS_HOOK" "$wo_file" "$result" "$log_file" >> "$log_file" 2>&1 || true
  fi

  # Archive WO
  local archive_dir="$ARCHIVE/$(date +%Y%m)"
  mkdir -p "$archive_dir"
  mv "$wo_file" "$archive_dir/"
  log INFO "Archived WO to: $archive_dir/$wo_name"

  return $([ "$result" = "success" ] && echo 0 || echo 1)
}

# ===== Main Loop =====
log INFO "WO Executor cycle starting"

# Safety checks
check_disk || { log ERROR "Safety check failed: disk space"; exit 1; }
check_circuit || { log WARN "Circuit breaker open, skipping cycle"; exit 0; }

# Find WO scripts
WO_FILES=()
if [[ -d "$IN_LLM" ]]; then
  for f in "$IN_LLM"/WO-*.zsh(N); do
    [[ -f "$f" ]] && WO_FILES+=("$f")
  done
fi

if (( ${#WO_FILES[@]} == 0 )); then
  log INFO "No WO scripts found"
  exit 0
fi

log INFO "Found ${#WO_FILES[@]} WO script(s)"

# Execute WOs (up to MAX_WOS per cycle)
executed=0
failures=0

for wo_file in "${WO_FILES[@]}"; do
  if (( executed >= MAX_WOS )); then
    log INFO "Max WOs per cycle reached ($MAX_WOS), stopping"
    break
  fi

  if execute_wo "$wo_file"; then
    executed=$((executed + 1))
    reset_failures
  else
    failures=$((failures + 1))
    record_failure
    log ERROR "WO execution failed: $(basename "$wo_file")"
  fi
done

log INFO "WO Executor cycle complete: $executed executed, $failures failed"

exit 0
