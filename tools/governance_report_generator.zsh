
# Claude Code Compliance Section
REDIS_PASS="changeme-02luka"
if command -v redis-cli >/dev/null 2>&1; then
  claude_data=$(redis-cli -a "$REDIS_PASS" HGETALL memory:agents:claude 2>/dev/null || echo "")
  
  if [[ -n "$claude_data" ]]; then
    hook_rate=$(echo "$claude_data" | grep "hook_success_rate" | tail -1 | awk '{print $2}' || echo "0")
    hook_success=$(echo "$claude_data" | grep "hook_success" | tail -1 | awk '{print $2}' || echo "0")
    hook_failures=$(echo "$claude_data" | grep "hook_failures" | tail -1 | awk '{print $2}' || echo "0")
    conflicts=$(echo "$claude_data" | grep "subagent_conflicts" | tail -1 | awk '{print $2}' || echo "0")
    conflict_rate=$(echo "$claude_data" | grep "conflict_rate" | tail -1 | awk '{print $2}' || echo "0")
    reviews=$(echo "$claude_data" | grep "reviews_completed" | tail -1 | awk '{print $2}' || echo "0")
    deploy_rate=$(echo "$claude_data" | grep "deployment_success_rate" | tail -1 | awk '{print $2}' || echo "0")
    deploy_success=$(echo "$claude_data" | grep "deployments_success" | tail -1 | awk '{print $2}' || echo "0")
    deploy_failed=$(echo "$claude_data" | grep "deployments_failed" | tail -1 | awk '{print $2}' || echo "0")
    
    # Calculate compliance score
    compliance_score=100
    [[ -n "$hook_rate" && $(echo "$hook_rate < 80" | bc 2>/dev/null || echo "0") -eq 1 ]] && compliance_score=$((compliance_score - 10))
    [[ -n "$conflict_rate" && $(echo "$conflict_rate > 10" | bc 2>/dev/null || echo "0") -eq 1 ]] && compliance_score=$((compliance_score - 5))
    [[ -n "$deploy_rate" && $(echo "$deploy_rate < 90" | bc 2>/dev/null || echo "0") -eq 1 ]] && compliance_score=$((compliance_score - 5))
    
    cat >> "$OUTPUT" <<CLAUDE_SECTION

## Claude Code Compliance

### Hook Execution
- Success Rate: ${hook_rate}%
- Total Executions: $((hook_success + hook_failures))
- Successes: ${hook_success}
- Failures: ${hook_failures}

### Code Review
- Reviews Completed: ${reviews}
- Subagent Conflicts: ${conflicts} (${conflict_rate}%)

### Deployment
- Success Rate: ${deploy_rate}%
- Successful: ${deploy_success}
- Failed: ${deploy_failed}

### Compliance Score: ${compliance_score}/100
CLAUDE_SECTION
  fi
fi
