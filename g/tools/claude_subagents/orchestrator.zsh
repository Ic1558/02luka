#!/usr/bin/env zsh
# Claude Code Subagent Orchestrator (Enhanced Production Edition)
# Purpose: Coordinate multiple subagents for tasks like code review
# Usage: orchestrator.zsh <strategy> <task> <num_agents>

set -euo pipefail

BASE="${LUKA_SOT:-$HOME/02luka}"
LOG_DIR="$BASE/logs"
REPORT_DIR="$BASE/g/reports/system"
mkdir -p "$LOG_DIR" "$REPORT_DIR"

# Orchestrator summary output (JSON)
: "${ORCH_SUMMARY_DIR:="$REPORT_DIR"}"
: "${ORCH_SUMMARY_PATH:="$ORCH_SUMMARY_DIR/claude_orchestrator_summary.json"}"

TMP_DIR="$(mktemp -d)"
trap 'rm -r -f "$TMP_DIR"' EXIT

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" >&2
}

current_millis() {
  local ts
  ts="$(date +%s%3N 2>/dev/null)" || ts="$(date +%s)000"
  printf '%s' "$ts"
}

json_escape() {
  local str="$1"
  str="${str//\\/\\\\}"
  str="${str//\"/\\\"}"
  str="${str//$'\n'/\\n}"
  str="${str//$'\r'/\\r}"
  printf '%s' "$str"
}

orch_write_summary_json() {
  local run_id="$1"
  local status="$2"
  local agent_count="$3"
  local agents_json="$4"
  local extra_meta_json="$5"

  mkdir -p "$ORCH_SUMMARY_DIR" || return 1

  local now_iso
  now_iso="$(date -u '+%Y-%m-%dT%H:%M:%SZ')" || now_iso=""

  [[ -z "$agents_json" ]] && agents_json="[]"
  [[ -z "$extra_meta_json" ]] && extra_meta_json="{}"

  local tmp="${ORCH_SUMMARY_PATH}.tmp"

  cat >"$tmp" <<EOF
{
  "version": "v2",
  "run_id": "${run_id}",
  "status": "${status}",
  "generated_at": "${now_iso}",
  "agent_count": ${agent_count},
  "meta": ${extra_meta_json},
  "agents": ${agents_json}
}
EOF

  mv "$tmp" "$ORCH_SUMMARY_PATH"
}

orch_build_agents_json() {
  local -n _agents_ref="$1"
  local -n _status_ref="$2"
  local -n _duration_ref="$3"
  local -n _error_ref="$4"

  local first=1
  printf '['
  for agent_name in "${_agents_ref[@]}"; do
    local st="${_status_ref[$agent_name]:-unknown}"
    local dur="${_duration_ref[$agent_name]:-0}"
    local err="${_error_ref[$agent_name]:-}"

    (( first )) || printf ','
    first=0

    printf '{'
    printf '"name":"%s",' "$(json_escape "$agent_name")"
    printf '"status":"%s",' "$(json_escape "$st")"
    printf '"duration_ms":%s' "${dur:-0}"

    if [[ -n "$err" ]]; then
      printf ',"error":"%s"' "$(json_escape "$err")"
    fi

    printf '}'
  done
  printf ']'
}

orch_compute_overall_status() {
  local -n _status_ref="$1"
  local ok=0
  local partial=0
  local failed=0

  for s in "${_status_ref[@]}"; do
    case "$s" in
      ok|success)
        (( ok++ ))
        ;;
      partial|degraded)
        (( partial++ ))
        ;;
      error|failed)
        (( failed++ ))
        ;;
      *)
        ;;
    esac
  done

  if (( failed > 0 )); then
    printf 'error'
  elif (( partial > 0 )); then
    printf 'partial'
  else
    printf 'ok'
  fi
}

orch_build_meta_json() {
  local -n _status_ref="$1"
  local -n _duration_ref="$2"

  local total=0
  local count=0
  local ok=0
  local partial=0
  local failed=0
  local other=0

  for s in "${_status_ref[@]}"; do
    case "$s" in
      ok|success)
        (( ok++ ))
        ;;
      partial|degraded)
        (( partial++ ))
        ;;
      error|failed)
        (( failed++ ))
        ;;
      *)
        (( other++ ))
        ;;
    esac
  done

  for d in "${_duration_ref[@]}"; do
    [[ -z "$d" ]] && continue
    if [[ "$d" =~ ^-?[0-9]+$ ]]; then
      (( total += d ))
      (( count++ ))
    fi
  done

  local avg_ms=0
  (( count > 0 )) && avg_ms=$(( total / count ))

  cat <<EOF
{
  "avg_agent_duration_ms": ${avg_ms},
  "agent_result_counts": {
    "ok": ${ok},
    "partial": ${partial},
    "error": ${failed},
    "other": ${other}
  }
}
EOF
}


run_agent() {
  local agent_id=$1
  local task=$2
  local tmpo="$TMP_DIR/out_${agent_id}.log"
  local tmpe="$TMP_DIR/err_${agent_id}.log"
  local rc=0
  local start_ms end_ms duration_ms

  start_ms="$(current_millis)"

  # Safe execution with error handling (check_runner pattern)
  {
    set +e
    eval "$task" >"$tmpo" 2>"$tmpe"
    rc=$?
    set -e
  } || true

  end_ms="$(current_millis)"

  if [[ "$start_ms" =~ ^[0-9]+$ && "$end_ms" =~ ^[0-9]+$ ]]; then
    duration_ms=$(( end_ms - start_ms ))
  else
    duration_ms=0
  fi

  echo "$rc" >"$TMP_DIR/rc_${agent_id}"
  echo "$duration_ms" >"$TMP_DIR/dur_${agent_id}"
  return 0
}

aggregate_results() {
  local num_agents=$1
  local strategy="$2"
  local winner="" best=0

  log "📊 Aggregating results from $num_agents agents..."

  typeset -a orchestrated_agents=()
  typeset -A agent_status
  typeset -A agent_duration_ms
  typeset -A agent_error

  for i in $(seq 1 $num_agents); do
    local agent_name="agent${i}"
    orchestrated_agents+=("$agent_name")

    local err="$(cat "$TMP_DIR/err_${i}.log" 2>/dev/null || echo "")"
    local rc="$(cat "$TMP_DIR/rc_${i}" 2>/dev/null || echo 1)"
    local dur="$(cat "$TMP_DIR/dur_${i}" 2>/dev/null || echo 0)"

    local score=$(( rc == 0 ? 100 : ((100 - (rc * 10)) < 0 ? 0 : (100 - (rc * 10))) ))

    local status="error"
    [[ "$rc" -eq 0 ]] && status="ok"

    agent_status[$agent_name]="$status"
    agent_duration_ms[$agent_name]="${dur:-0}"
    agent_error[$agent_name]="$err"

    if (( score > best )); then
      best=$score
      winner="$agent_name"
    fi
  done

  local agents_json
  agents_json="$(orch_build_agents_json orchestrated_agents agent_status agent_duration_ms agent_error)"

  local overall_status
  overall_status="$(orch_compute_overall_status agent_status)"

  local meta_json
  meta_json="$(orch_build_meta_json agent_status agent_duration_ms)"

  orch_write_summary_json \
    "$ORCH_RUN_ID" \
    "$overall_status" \
    "${#orchestrated_agents[@]}" \
    "$agents_json" \
    "$meta_json"

  # Log metrics
  echo "$(date '+%F %T') | run_id=$ORCH_RUN_ID | strategy=$strategy | agents=$num_agents | winner=$winner | score=$best"     >> "$LOG_DIR/claude_subagent_metrics.log"

  log "✅ Results aggregated. Winner: $winner (score: $best)"
  echo "$ORCH_SUMMARY_PATH"
}


usage() {
  echo "Usage: $0 <strategy> <task> <num_agents>" >&2
  echo "  strategy: review, compete, or collaborate" >&2
  echo "  task: Command or script to run" >&2
  echo "  num_agents: Number of agents (1-10)" >&2
  exit 1
}

# Validate arguments
[[ $# -lt 3 ]] && usage

STRATEGY="$1"
TASK="$2"
NUM_AGENTS="$3"
: "${ORCH_RUN_ID:="orch-$(date -u '+%Y%m%dT%H%M%SZ')"}"

# Validate strategy
case "$STRATEGY" in
  review|compete|collaborate)
    ;;
  *)
    log "⚠️  Unknown strategy: $STRATEGY (using 'review')"
    STRATEGY="review"
    ;;
esac

# Validate num_agents
if ! [[ "$NUM_AGENTS" =~ ^[0-9]+$ ]] || [[ "$NUM_AGENTS" -lt 1 ]] || [[ "$NUM_AGENTS" -gt 10 ]]; then
  log "⚠️  Invalid num_agents: $NUM_AGENTS (using 2)"
  NUM_AGENTS=2
fi

log "🔀 Orchestrator: strategy=$STRATEGY, task=$TASK, agents=$NUM_AGENTS"

# Run agents in parallel
for i in $(seq 1 $NUM_AGENTS); do
  run_agent "$i" "$TASK" &
done

# Wait for all agents with safety guard
wait || {
  log "⚠️  Some subagents failed but continuing with partial results"
}

# Aggregate results
aggregate_results "$NUM_AGENTS" "$STRATEGY"

log "✅ Orchestration complete"
