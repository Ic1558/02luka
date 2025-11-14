#!/usr/bin/env bash
#
# CLS Web CI Gate - Phase 20
#
# Load testing script for CLS Web integration and CI coordinator.
# Generates synthetic load to test event routing, session management,
# and coordinator resilience.
#
# Usage:
#   ./cls_web_gate.sh [options]
#
# Options:
#   --concurrent N       Number of concurrent sessions (default: 10)
#   --duration N         Test duration in seconds (default: 900)
#   --events-per-min N   Events per minute (default: 50)
#   --help              Show this help message

set -euo pipefail

# Default configuration
CONCURRENT=10
DURATION=900
EVENTS_PER_MIN=50
REDIS_HOST="${REDIS_HOST:-127.0.0.1}"
REDIS_PORT="${REDIS_PORT:-6379}"
REDIS_PASSWORD="${REDIS_PASSWORD:-}"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --concurrent)
      CONCURRENT="$2"
      shift 2
      ;;
    --duration)
      DURATION="$2"
      shift 2
      ;;
    --events-per-min)
      EVENTS_PER_MIN="$2"
      shift 2
      ;;
    --help)
      sed -n '2,/^$/p' "$0" | sed 's/^# //; s/^#//'
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Colors and formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

# Logging functions
log_info() {
  echo -e "${BLUE}[INFO]${RESET} $*"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${RESET} $*"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${RESET} $*"
}

log_error() {
  echo -e "${RED}[ERROR]${RESET} $*"
}

log_section() {
  echo ""
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${BOLD}$*${RESET}"
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

# Redis helper
redis_cmd() {
  local args=("-h" "$REDIS_HOST" "-p" "$REDIS_PORT")
  if [[ -n "$REDIS_PASSWORD" ]]; then
    args+=("-a" "$REDIS_PASSWORD")
  fi
  redis-cli "${args[@]}" "$@"
}

# Generate session ID
generate_session_id() {
  echo "sess_$(date +%s)_$(openssl rand -hex 4 2>/dev/null || head -c 8 /dev/urandom | xxd -p)"
}

# Generate event ID
generate_event_id() {
  echo "evt_$(date +%s)_$(openssl rand -hex 4 2>/dev/null || head -c 8 /dev/urandom | xxd -p)"
}

# Push event to Redis queue
push_event() {
  local event_json="$1"
  redis_cmd rpush "cls:events" "$event_json" > /dev/null
}

# Create session event
create_session_event() {
  local session_id="$1"
  local metadata="${2:-{}}"

  cat <<EOF
{
  "type": "session:create",
  "sessionId": "$session_id",
  "timestamp": $(date +%s)000,
  "data": $metadata
}
EOF
}

# Update session event
update_session_event() {
  local session_id="$1"
  local updates="${2:-{}}"

  cat <<EOF
{
  "type": "session:update",
  "sessionId": "$session_id",
  "timestamp": $(date +%s)000,
  "data": $updates
}
EOF
}

# End session event
end_session_event() {
  local session_id="$1"
  local status="${2:-completed}"

  cat <<EOF
{
  "type": "session:end",
  "sessionId": "$session_id",
  "timestamp": $(date +%s)000,
  "data": {
    "status": "$status"
  }
}
EOF
}

# CI event
ci_event() {
  local event_type="$1"
  local lane="$2"
  local priority="${3:-normal}"

  cat <<EOF
{
  "type": "ci:$event_type",
  "lane": "$lane",
  "priority": "$priority",
  "timestamp": $(date +%s)000,
  "data": {
    "eventId": "$(generate_event_id)",
    "testRun": true
  }
}
EOF
}

# Main test function
run_load_test() {
  log_section "Phase 20: CLS Web Load Test"

  log_info "Test Configuration:"
  log_info "  Concurrent sessions: $CONCURRENT"
  log_info "  Duration: ${DURATION}s"
  log_info "  Events per minute: $EVENTS_PER_MIN"
  log_info "  Total expected events: $((DURATION * EVENTS_PER_MIN / 60))"

  # Check Redis connectivity
  log_section "Checking Redis Connection"
  if redis_cmd ping > /dev/null 2>&1; then
    log_success "Redis is reachable at ${REDIS_HOST}:${REDIS_PORT}"
  else
    log_error "Cannot connect to Redis at ${REDIS_HOST}:${REDIS_PORT}"
    exit 1
  fi

  # Create sessions
  log_section "Creating Test Sessions"
  declare -a session_ids=()
  for i in $(seq 1 "$CONCURRENT"); do
    local session_id
    session_id=$(generate_session_id)
    session_ids+=("$session_id")

    local metadata
    metadata=$(cat <<EOF
{
  "testRun": true,
  "sessionIndex": $i,
  "loadLevel": "heavy",
  "phase": 20
}
EOF
)

    local event
    event=$(create_session_event "$session_id" "$metadata")
    push_event "$event"

    log_info "Created session $i/$CONCURRENT: $session_id"
  done

  # Calculate event interval
  local events_per_sec=$(echo "scale=2; $EVENTS_PER_MIN / 60" | bc)
  local interval_sec=$(echo "scale=4; 1 / $events_per_sec" | bc)
  log_info "Event interval: ${interval_sec}s (${events_per_sec} events/sec)"

  # Generate load
  log_section "Generating Load Events"
  local start_time
  start_time=$(date +%s)
  local end_time=$((start_time + DURATION))
  local event_count=0

  local event_types=("build" "test" "health")
  local lanes=("gpt4" "claude_web" "crude")
  local priorities=("high" "normal" "low")

  while [[ $(date +%s) -lt $end_time ]]; do
    # Send CI event
    local event_type="${event_types[$((RANDOM % ${#event_types[@]}))]}"
    local lane="${lanes[$((RANDOM % ${#lanes[@]}))]}"
    local priority="${priorities[$((RANDOM % ${#priorities[@]}))]}"

    local event
    event=$(ci_event "$event_type" "$lane" "$priority")
    redis_cmd rpush "ci:queue:$priority" "$event" > /dev/null

    event_count=$((event_count + 1))

    # Update random session
    if [[ $((event_count % 5)) -eq 0 ]]; then
      local random_session="${session_ids[$((RANDOM % ${#session_ids[@]}))]}"
      local update
      update=$(cat <<EOF
{
  "eventsProcessed": $event_count,
  "lastEventType": "$event_type"
}
EOF
)
      local update_event
      update_event=$(update_session_event "$random_session" "$update")
      push_event "$update_event"
    fi

    # Progress update
    if [[ $((event_count % 50)) -eq 0 ]]; then
      local elapsed=$(($(date +%s) - start_time))
      local remaining=$((DURATION - elapsed))
      log_info "Progress: ${event_count} events sent, ${elapsed}s elapsed, ${remaining}s remaining"

      # Show queue depths
      local high_depth
      local normal_depth
      local low_depth
      high_depth=$(redis_cmd llen "ci:queue:high" 2>/dev/null || echo 0)
      normal_depth=$(redis_cmd llen "ci:queue:normal" 2>/dev/null || echo 0)
      low_depth=$(redis_cmd llen "ci:queue:low" 2>/dev/null || echo 0)
      log_info "Queue depths: high=$high_depth, normal=$normal_depth, low=$low_depth"
    fi

    # Sleep for interval
    sleep "$interval_sec"
  done

  log_success "Generated $event_count events over ${DURATION}s"

  # End sessions
  log_section "Ending Test Sessions"
  for i in "${!session_ids[@]}"; do
    local session_id="${session_ids[$i]}"
    local status="completed"

    # Randomly mark some as failed for testing
    if [[ $((RANDOM % 10)) -eq 0 ]]; then
      status="failed"
    fi

    local event
    event=$(end_session_event "$session_id" "$status")
    push_event "$event"

    log_info "Ended session $((i + 1))/${#session_ids[@]}: $session_id ($status)"
  done

  # Wait for processing
  log_section "Waiting for Event Processing"
  log_info "Giving systems time to process remaining events..."
  sleep 10

  # Check queue depths
  log_info "Final queue depths:"
  local high_depth
  local normal_depth
  local low_depth
  local dlq_depth
  high_depth=$(redis_cmd llen "ci:queue:high" 2>/dev/null || echo 0)
  normal_depth=$(redis_cmd llen "ci:queue:normal" 2>/dev/null || echo 0)
  low_depth=$(redis_cmd llen "ci:queue:low" 2>/dev/null || echo 0)
  dlq_depth=$(redis_cmd llen "ci:queue:dlq" 2>/dev/null || echo 0)

  log_info "  High priority: $high_depth"
  log_info "  Normal priority: $normal_depth"
  log_info "  Low priority: $low_depth"
  log_info "  Dead letter queue: $dlq_depth"

  # Summary
  log_section "Load Test Summary"
  log_success "Test completed successfully"
  log_info "  Sessions created: ${#session_ids[@]}"
  log_info "  Events generated: $event_count"
  log_info "  Duration: ${DURATION}s"
  log_info "  Average rate: $(echo "scale=2; $event_count / $DURATION" | bc) events/sec"

  if [[ $dlq_depth -gt 0 ]]; then
    log_warn "Dead letter queue has $dlq_depth events - check g/reports/cls_web/dlq_*.json"
  fi
}

# Main execution
main() {
  log_info "Starting CLS Web CI Gate"
  log_info "Redis: ${REDIS_HOST}:${REDIS_PORT}"

  # Create logs directory if needed
  mkdir -p logs

  # Run the test
  run_load_test

  log_section "Test Complete"
  log_success "CLS Web load test finished"
  log_info "Check g/reports/cls_web/ for detailed reports"
}

main
