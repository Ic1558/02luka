#!/usr/bin/env zsh
set -euo pipefail

REPO="$HOME/02luka"
REDIS_PASS="changeme-02luka"
REDIS_CLI="redis-cli -a $REDIS_PASS"
MEM_SYNC="$REPO/tools/memory_sync.sh"

# Collect Claude Code metrics
collect_metrics() {
  local hook_success=0
  local hook_failures=0
  local subagent_conflicts=0
  local reviews_completed=0
  local deployments_success=0
  local deployments_failed=0
  
  # Count hook executions from logs (last 24h)
  if [[ -f "$REPO/logs/claude_hooks.log" ]]; then
    hook_success=$(grep -c "✅" "$REPO/logs/claude_hooks.log" 2>/dev/null || echo "0")
    hook_failures=$(grep -c "❌" "$REPO/logs/claude_hooks.log" 2>/dev/null || echo "0")
  fi
  
  # Count subagent conflicts (from review logs)
  if [[ -f "$REPO/logs/claude_reviews.log" ]]; then
    subagent_conflicts=$(grep -c "conflict\|disagreement" "$REPO/logs/claude_reviews.log" 2>/dev/null || echo "0")
    reviews_completed=$(grep -c "review completed" "$REPO/logs/claude_reviews.log" 2>/dev/null || echo "0")
  fi
  
  # Count deployments (from deployment logs)
  if [[ -f "$REPO/logs/claude_deployments.log" ]]; then
    deployments_success=$(grep -c "✅.*deployment.*success" "$REPO/logs/claude_deployments.log" 2>/dev/null || echo "0")
    deployments_failed=$(grep -c "❌.*deployment.*failed" "$REPO/logs/claude_deployments.log" 2>/dev/null || echo "0")
  fi
  
  # Calculate rates
  local total_hooks=$((hook_success + hook_failures))
  local hook_success_rate=0
  if [[ $total_hooks -gt 0 ]]; then
    hook_success_rate=$(printf '%.2f' "$(echo "$hook_success $total_hooks" | awk '{printf ($1/$2)*100}')")
  fi
  
  local total_deployments=$((deployments_success + deployments_failed))
  local deployment_success_rate=0
  if [[ $total_deployments -gt 0 ]]; then
    deployment_success_rate=$(printf '%.2f' "$(echo "$deployments_success $total_deployments" | awk '{printf ($1/$2)*100}')")
  fi
  
  local conflict_rate=0
  if [[ $reviews_completed -gt 0 ]]; then
    conflict_rate=$(printf '%.2f' "$(echo "$subagent_conflicts $reviews_completed" | awk '{printf ($1/$2)*100}')")
  fi
  
  # Update Redis
  if command -v redis-cli >/dev/null 2>&1; then
    $REDIS_CLI HSET memory:agents:claude status active >/dev/null 2>&1 || true
    $REDIS_CLI HSET memory:agents:claude hook_success_rate "$hook_success_rate" >/dev/null 2>&1 || true
    $REDIS_CLI HSET memory:agents:claude hook_success "$hook_success" >/dev/null 2>&1 || true
    $REDIS_CLI HSET memory:agents:claude hook_failures "$hook_failures" >/dev/null 2>&1 || true
    $REDIS_CLI HSET memory:agents:claude subagent_conflicts "$subagent_conflicts" >/dev/null 2>&1 || true
    $REDIS_CLI HSET memory:agents:claude conflict_rate "$conflict_rate" >/dev/null 2>&1 || true
    $REDIS_CLI HSET memory:agents:claude reviews_completed "$reviews_completed" >/dev/null 2>&1 || true
    $REDIS_CLI HSET memory:agents:claude deployment_success_rate "$deployment_success_rate" >/dev/null 2>&1 || true
    $REDIS_CLI HSET memory:agents:claude deployments_success "$deployments_success" >/dev/null 2>&1 || true
    $REDIS_CLI HSET memory:agents:claude deployments_failed "$deployments_failed" >/dev/null 2>&1 || true
    $REDIS_CLI HSET memory:agents:claude last_update "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >/dev/null 2>&1 || true
    
    # Publish update
    $REDIS_CLI PUBLISH memory:updates "{\"agent\":\"claude\",\"event\":\"metrics_update\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" >/dev/null 2>&1 || true
  fi
  
  # Update shared memory
  if [[ -f "$MEM_SYNC" ]]; then
    "$MEM_SYNC" update claude active >/dev/null 2>&1 || true
  fi
  
  # Output summary
  echo "Claude Code Metrics:"
  echo "  Hook Success Rate: ${hook_success_rate}%"
  echo "  Subagent Conflicts: ${subagent_conflicts} (${conflict_rate}%)"
  echo "  Reviews Completed: ${reviews_completed}"
  echo "  Deployment Success Rate: ${deployment_success_rate}%"
}

collect_metrics
