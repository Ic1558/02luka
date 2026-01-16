#!/usr/bin/env zsh
# GitHub Actions Monitoring Agent
# Runs in background, monitors failures, and shows macOS notifications
# Usage: tools/gh_monitor_agent.zsh [workflow_name] [interval]

set -euo pipefail

WORKFLOW="${1:-}"
INTERVAL="${2:-30}"
LOG_DIR="${HOME}/02luka/g/reports/gh_failures"
AGENT_LOG="${HOME}/02luka/logs/gh_monitor_agent.stdout.log"
mkdir -p "$LOG_DIR"
mkdir -p "$(dirname "$AGENT_LOG")"

# Track seen runs to avoid duplicate notifications
SEEN_RUNS_FILE="${LOG_DIR}/.seen_runs"
touch "$SEEN_RUNS_FILE"

# Function to show macOS notification
show_notification() {
  local title="$1"
  local message="$2"
  local subtitle="$3"
  
  # Use osascript for macOS notifications
  osascript -e "display notification \"$message\" with title \"$title\" subtitle \"$subtitle\" sound name \"Glass\"" 2>/dev/null || true
  
  # Also log to agent log
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] NOTIFICATION: $title - $message" >> "$AGENT_LOG"
}

# Function to check and process failures
check_failures() {
  # Get latest runs
  local runs
  if [ -n "$WORKFLOW" ]; then
    runs=$(gh run list --workflow "$WORKFLOW" --limit 10 --json databaseId,displayTitle,status,conclusion,createdAt,workflowName,event,url 2>/dev/null || echo "[]")
  else
    runs=$(gh run list --limit 10 --json databaseId,displayTitle,status,conclusion,createdAt,workflowName,event,url 2>/dev/null || echo "[]")
  fi
  
  # Check for failures
  local failed_runs
  failed_runs=$(echo "$runs" | jq -r '.[] | select(.conclusion == "failure") | .databaseId' 2>/dev/null || echo "")
  
  for run_id in $failed_runs; do
    # Check if we've already processed this run
    if grep -q "^${run_id}$" "$SEEN_RUNS_FILE" 2>/dev/null; then
      continue
    fi
    
    # Mark as seen
    echo "$run_id" >> "$SEEN_RUNS_FILE"
    
    # Get run details
    local run_info
    run_info=$(echo "$runs" | jq -r ".[] | select(.databaseId == $run_id)")
    local workflow_name
    workflow_name=$(echo "$run_info" | jq -r '.workflowName')
    local title
    title=$(echo "$run_info" | jq -r '.displayTitle')
    local url
    url=$(echo "$run_info" | jq -r '.url')
    local event
    event=$(echo "$run_info" | jq -r '.event')
    
    # Extract logs
    local log_file
    log_file="${LOG_DIR}/${run_id}_${workflow_name//\//_}_$(date +%Y%m%d_%H%M%S).log"
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] FAILURE DETECTED: Run $run_id - $workflow_name" >> "$AGENT_LOG"
    
    if gh run view "$run_id" --log > "$log_file" 2>&1; then
      local log_size
      log_size=$(du -h "$log_file" | cut -f1)
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] Logs extracted: $log_file (${log_size})" >> "$AGENT_LOG"
      
      # Get error summary
      local error_summary
      error_summary=$(grep -i "error\|failed\|failure" "$log_file" | head -3 | sed 's/^[[:space:]]*//' | tr '\n' '; ' | cut -c1-100)
      
      # Show notification
      show_notification \
        "❌ GitHub Actions Failure" \
        "$workflow_name failed" \
        "Run #$run_id - Logs saved"
      
      # Log details
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] Details: $title | Event: $event | URL: $url" >> "$AGENT_LOG"
      if [ -n "$error_summary" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Error summary: $error_summary" >> "$AGENT_LOG"
      fi
    else
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: Failed to extract logs for run $run_id" >> "$AGENT_LOG"
      show_notification \
        "⚠️ GitHub Actions Failure" \
        "$workflow_name failed (log extraction failed)" \
        "Run #$run_id"
    fi
  done
}

# Main loop
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting GitHub Actions Monitor Agent" >> "$AGENT_LOG"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Workflow: ${WORKFLOW:-all workflows}" >> "$AGENT_LOG"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Interval: ${INTERVAL}s" >> "$AGENT_LOG"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Log directory: $LOG_DIR" >> "$AGENT_LOG"

# Initial check
check_failures

# Continuous monitoring
while true; do
  sleep "$INTERVAL"
  check_failures
done
