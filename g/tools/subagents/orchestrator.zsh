#!/usr/bin/env zsh
# Subagent Orchestrator (Backend-Agnostic)
# Purpose: Coordinate multiple subagents for tasks like code review
# Usage: orchestrator.zsh <strategy> <task> <num_agents> [BACKEND=cls]

set -euo pipefail

BASE="${LUKA_SOT:-$HOME/02luka}"
LOG_DIR="$BASE/logs"
REPORT_DIR="$BASE/g/reports/system"
mkdir -p "$LOG_DIR" "$REPORT_DIR"

# Backend selection (default: CLS)
BACKEND="${BACKEND:-cls}"
ADAPTER_DIR="$BASE/tools/subagents/adapters"

# Load backend adapter
if [[ ! -f "$ADAPTER_DIR/${BACKEND}.zsh" ]]; then
  echo "⚠️  Backend adapter not found: $ADAPTER_DIR/${BACKEND}.zsh (using cls)" >&2
  BACKEND="cls"
fi

source "$ADAPTER_DIR/${BACKEND}.zsh" || {
  echo "❌ Failed to load backend adapter: $BACKEND" >&2
  exit 1
}

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" >&2
}

run_agent() {
  local agent_id=$1
  local task=$2
  local tmpo="$TMP_DIR/out_${agent_id}.log"
  local tmpe="$TMP_DIR/err_${agent_id}.log"
  local rc=0
  
  # Safe execution with error handling (check_runner pattern)
  # Use backend adapter's run_backend_task function
  {
    set +e
    run_backend_task "$task" >"$tmpo" 2>"$tmpe"
    rc=$?
    set -e
  } || true
  
  echo "$rc" >"$TMP_DIR/rc_${agent_id}"
  return 0
}

aggregate_results() {
  local num_agents=$1
  local strategy="$2"
  local summary_json="$REPORT_DIR/subagent_orchestrator_summary.json"
  local winner="" best=0
  local agents_json=""
  
  log "📊 Aggregating results from $num_agents agents (backend: $BACKEND)..."
  
  # Build agents array
  for i in $(seq 1 $num_agents); do
    local out="$(cat "$TMP_DIR/out_${i}.log" 2>/dev/null || echo "")"
    local err="$(cat "$TMP_DIR/err_${i}.log" 2>/dev/null || echo "")"
    local rc="$(cat "$TMP_DIR/rc_${i}" 2>/dev/null || echo 1)"
    
    # Simple scoring: 100 - (exit_code * 10), min 0
    local score=$(( rc == 0 ? 100 : ((100 - (rc * 10)) < 0 ? 0 : (100 - (rc * 10))) ))
    
    # Escape JSON special characters
    out="${out//\"/\\\"}"
    out="${out//$'\n'/\\n}"
    err="${err//\"/\\\"}"
    err="${err//$'\n'/\\n}"
    
    agents_json+="{\"id\":$i,\"exit_code\":$rc,\"score\":$score,\"stdout\":\"$out\",\"stderr\":\"$err\"}"
    [[ $i -lt $num_agents ]] && agents_json+=","
    
    if (( score > best )); then
      best=$score
      winner="agent${i}"
    fi
  done
  
  # Write JSON summary with backend tag
  {
    echo "{"
    echo "  \"backend\": \"$BACKEND\","
    echo "  \"strategy\": \"$strategy\","
    echo "  \"num_agents\": $num_agents,"
    echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
    echo "  \"winner\": \"$winner\","
    echo "  \"best_score\": $best,"
    echo "  \"agents\": [$agents_json]"
    echo "}"
  } > "$summary_json"
  
  # Validate JSON
  if command -v jq >/dev/null 2>&1; then
    jq . "$summary_json" > "$summary_json.tmp" 2>/dev/null && mv "$summary_json.tmp" "$summary_json" || true
  fi
  
  # Log metrics with backend tag
  echo "$(date '+%F %T') | backend=$BACKEND | strategy=$strategy | agents=$num_agents | winner=$winner | score=$best" \
    >> "$LOG_DIR/subagent_metrics.log"
  
  log "✅ Results aggregated. Winner: $winner (score: $best, backend: $BACKEND)"
  echo "$summary_json"
}

usage() {
  echo "Usage: $0 <strategy> <task> <num_agents> [BACKEND=cls]" >&2
  echo "  strategy: review, compete, or collaborate" >&2
  echo "  task: Command or script to run" >&2
  echo "  num_agents: Number of agents (1-10)" >&2
  echo "  BACKEND: cls (default) or claude" >&2
  exit 1
}

# Validate arguments
[[ $# -lt 3 ]] && usage

STRATEGY="$1"
TASK="$2"
NUM_AGENTS="$3"

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

log "🔀 Orchestrator: backend=$BACKEND, strategy=$STRATEGY, task=$TASK, agents=$NUM_AGENTS"

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

log "✅ Orchestration complete (backend: $BACKEND)"
