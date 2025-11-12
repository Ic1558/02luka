
# Claude Code health checks
REDIS_PASS="changeme-02luka"
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
      
      # Send alert (reuse existing Telegram logic)
      if [[ -n "${TG_TOKEN:-}" && -n "${TG_CHAT:-}" ]]; then
        curl -sS -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
          -d chat_id="${TG_CHAT}" \
          --data-urlencode text="${msg}" >/dev/null 2>&1 || true
      fi
    fi
  fi
  
  if [[ -n "$conflict_rate" ]]; then
    conflict_int=${conflict_rate%.*}
    if [[ $conflict_int -gt $CONFLICT_THRESHOLD ]]; then
      msg="[GOVERNANCE] Alert: Claude Code Subagent Conflicts High
Component: claude_code
Issue: Subagent conflict rate ${conflict_rate}% (threshold: ${CONFLICT_THRESHOLD}%)
Action: Review subagent coordination"
      
      if [[ -n "${TG_TOKEN:-}" && -n "${TG_CHAT:-}" ]]; then
        curl -sS -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
          -d chat_id="${TG_CHAT}" \
          --data-urlencode text="${msg}" >/dev/null 2>&1 || true
      fi
    fi
  fi
fi
