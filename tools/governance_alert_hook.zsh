#!/usr/bin/env zsh
set -euo pipefail

# Phase 5: Governance Alert Hook
# Send Telegram alerts when system health degrades

REPO="$HOME/02luka"
REDIS_PASS="${REDIS_PASSWORD:-changeme-02luka}"
[[ -n "${REDIS_ALT_PASSWORD:-}" ]] && REDIS_PASS="$REDIS_ALT_PASSWORD"

TG_TOKEN="${GPT_ALERTS_BOT_TOKEN:-}"
TG_CHAT="${GPT_ALERTS_CHAT_ID:-}"

HEALTH_THRESHOLD=${GOVERNANCE_HEALTH_THRESHOLD:-80}
DEDUP_HOURS=${GOVERNANCE_ALERT_DEDUP_HOURS:-1}
STATE_FILE="$REPO/logs/governance_alerts.state"

mkdir -p "$(dirname "$STATE_FILE")"

# Function to check if alert was sent recently
should_send_alert() {
  local alert_key="$1"
  local hours="$2"
  
  if [[ ! -f "$STATE_FILE" ]]; then
    return 0  # Send if no state file
  fi
  
  local last_sent=$(grep "^${alert_key}:" "$STATE_FILE" 2>/dev/null | cut -d: -f2 || echo "0")
  local now=$(date +%s)
  local threshold=$((now - hours * 3600))
  
  if [[ $last_sent -lt $threshold ]]; then
    return 0  # Send alert
  else
    return 1  # Don't send (recently sent)
  fi
}

# Function to record alert sent
record_alert() {
  local alert_key="$1"
  local timestamp=$(date +%s)
  
  if [[ -f "$STATE_FILE" ]]; then
    grep -v "^${alert_key}:" "$STATE_FILE" > "${STATE_FILE}.tmp" 2>/dev/null || true
    mv "${STATE_FILE}.tmp" "$STATE_FILE" 2>/dev/null || true
  fi
  
  echo "${alert_key}:${timestamp}" >> "$STATE_FILE"
}

# Function to send Telegram alert
send_alert() {
  local msg="$1"
  local alert_key="$2"
  
  if [[ -z "$TG_TOKEN" || -z "$TG_CHAT" ]]; then
    echo "⚠️  Telegram credentials not configured (GPT_ALERTS_BOT_TOKEN, GPT_ALERTS_CHAT_ID)"
    return 1
  fi
  
  if should_send_alert "$alert_key" "$DEDUP_HOURS"; then
    if curl -sS -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
      -d chat_id="${TG_CHAT}" \
      --data-urlencode text="${msg}" >/dev/null 2>&1; then
      record_alert "$alert_key"
      echo "✅ Alert sent: $alert_key"
      return 0
    else
      echo "❌ Failed to send alert: $alert_key"
      return 1
    fi
  else
    echo "ℹ️  Alert recently sent, skipping: $alert_key"
    return 0
  fi
}

# Check health score
HEALTH_OUTPUT=$(tools/memory_hub_health.zsh 2>&1 || echo "")
HEALTH_SCORE=$(echo "$HEALTH_OUTPUT" | grep "Health Score:" | sed 's/.*Health Score: //' | sed 's/%//' || echo "100")

if [[ -n "$HEALTH_SCORE" && "$HEALTH_SCORE" != "N/A" && "$HEALTH_SCORE" -lt "$HEALTH_THRESHOLD" ]]; then
  msg="[GOVERNANCE] Alert: System Health Degraded
Component: system_health
Issue: Health score ${HEALTH_SCORE}% (threshold: ${HEALTH_THRESHOLD}%)
Action: Review system health check output"
  
  send_alert "$msg" "health_low_${HEALTH_SCORE}"
fi

# Check daily digest (missing for > 24 hours)
TODAY=$(date +%Y%m%d)
YESTERDAY=$(date -v-1d +%Y%m%d 2>/dev/null || date -d "yesterday" +%Y%m%d 2>/dev/null || echo "")
DIGEST_TODAY="$REPO/g/reports/memory_digest_${TODAY}.md"
DIGEST_YESTERDAY="$REPO/g/reports/memory_digest_${YESTERDAY}.md"

if [[ ! -f "$DIGEST_TODAY" && ! -f "$DIGEST_YESTERDAY" ]]; then
  msg="[GOVERNANCE] Alert: Daily Digest Missing
Component: memory_digest
Issue: Daily digest missing for > 24 hours
Action: Check digest generation and LaunchAgent"
  
  send_alert "$msg" "digest_missing"
fi

# Check Redis connectivity
if ! redis-cli -a "$REDIS_PASS" PING >/dev/null 2>&1; then
  msg="[GOVERNANCE] Alert: Redis Connectivity Lost
Component: redis
Issue: Cannot connect to Redis server
Action: Check Redis service status"
  
  send_alert "$msg" "redis_disconnected"
fi

# Check hub LaunchAgent
if ! launchctl list 2>/dev/null | grep -q com.02luka.memory.hub; then
  msg="[GOVERNANCE] Alert: Memory Hub Not Running
Component: memory_hub
Issue: LaunchAgent com.02luka.memory.hub not loaded
Action: Check LaunchAgent status and logs"
  
  send_alert "$msg" "hub_not_running"
fi

# Claude Code health checks
HOOK_FAILURE_THRESHOLD=${CLAUDE_CODE_HOOK_FAILURE_THRESHOLD:-20}
CONFLICT_THRESHOLD=${CLAUDE_CODE_SUBAGENT_CONFLICT_THRESHOLD:-10}

if command -v redis-cli >/dev/null 2>&1; then
  hook_rate=$(redis-cli -a "$REDIS_PASS" HGET memory:agents:claude hook_success_rate 2>/dev/null || echo "100")
  conflict_rate=$(redis-cli -a "$REDIS_PASS" HGET memory:agents:claude conflict_rate 2>/dev/null || echo "0")
  
  if [[ -n "$hook_rate" ]]; then
    hook_failure_rate=$((100 - ${hook_rate%.*}))
    if [[ $hook_failure_rate -gt $HOOK_FAILURE_THRESHOLD ]]; then
      msg="[GOVERNANCE] Alert: Claude Code Health Degraded
Component: claude_code
Issue: Hook failure rate ${hook_failure_rate}% (threshold: ${HOOK_FAILURE_THRESHOLD}%)
Health Score: $((100 - hook_failure_rate))%
Action: Review hook logs, check dependencies"
      
      send_alert "$msg" "claude_hook_failure"
    fi
  fi
  
  if [[ -n "$conflict_rate" ]]; then
    conflict_int=${conflict_rate%.*}
    if [[ $conflict_int -gt $CONFLICT_THRESHOLD ]]; then
      msg="[GOVERNANCE] Alert: Claude Code Subagent Conflicts High
Component: claude_code
Issue: Subagent conflict rate ${conflict_rate}% (threshold: ${CONFLICT_THRESHOLD}%)
Action: Review subagent coordination"
      
      send_alert "$msg" "claude_conflict_high"
    fi
  fi
fi

echo "✅ Alert hook completed"
