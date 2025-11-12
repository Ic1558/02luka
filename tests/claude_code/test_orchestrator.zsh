#!/usr/bin/env zsh
# Smoke Test for Claude Code Orchestrator
# Purpose: Verify orchestrator and compare_results functionality
# Usage: tests/claude_code/test_orchestrator.zsh

set -euo pipefail

BASE="${LUKA_SOT:-$HOME/02luka}"
cd "$BASE"

REPORT_DIR="$BASE/g/reports/system"
ORCHESTRATOR="$BASE/tools/subagents/orchestrator.zsh"
COMPARE="$BASE/tools/subagents/compare_results.zsh"

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" >&2
}

log "🧪 Starting orchestrator smoke test..."

# Test 1: Verify orchestrator exists and is executable
if [[ ! -x "$ORCHESTRATOR" ]]; then
  log "❌ Orchestrator not found or not executable: $ORCHESTRATOR"
  exit 1
fi
log "✅ Orchestrator found and executable"

# Test 2: Verify compare_results exists and is executable
if [[ ! -x "$COMPARE" ]]; then
  log "❌ Compare results not found or not executable: $COMPARE"
  exit 1
fi
log "✅ Compare results found and executable"

# Test 3: Run orchestrator with simple task
log "▶ Running orchestrator with compete strategy..."
"$ORCHESTRATOR" compete "echo ok_from_agent" 3 || {
  log "❌ Orchestrator execution failed"
  exit 1
}
log "✅ Orchestrator execution completed"

# Test 4: Verify summary JSON was created
SUMMARY_JSON="$REPORT_DIR/subagent_orchestrator_summary.json"
# Fallback to old filename for backward compatibility
[[ ! -f "$SUMMARY_JSON" ]] && SUMMARY_JSON="$REPORT_DIR/claude_orchestrator_summary.json"
if [[ ! -f "$SUMMARY_JSON" ]]; then
  log "❌ Summary JSON not found: $SUMMARY_JSON"
  exit 1
fi
log "✅ Summary JSON created"

# Test 5: Verify summary JSON has required fields
if command -v jq >/dev/null 2>&1; then
  if ! jq -e '.winner' "$SUMMARY_JSON" >/dev/null 2>&1; then
    log "❌ Summary JSON missing 'winner' field"
    exit 1
  fi
  if ! jq -e '.best_score' "$SUMMARY_JSON" >/dev/null 2>&1; then
    log "❌ Summary JSON missing 'best_score' field"
    exit 1
  fi
  if ! jq -e '.agents' "$SUMMARY_JSON" >/dev/null 2>&1; then
    log "❌ Summary JSON missing 'agents' field"
    exit 1
  fi
  log "✅ Summary JSON has all required fields"
else
  if ! grep -q '"winner"' "$SUMMARY_JSON"; then
    log "❌ Summary JSON missing 'winner' field (jq not available for validation)"
    exit 1
  fi
  log "✅ Summary JSON contains 'winner' field (jq not available, basic check)"
fi

# Test 6: Run compare_results
log "▶ Running compare_results..."
"$COMPARE" || {
  log "❌ Compare results execution failed"
  exit 1
}
log "✅ Compare results execution completed"

# Test 7: Verify compare JSON was created
COMPARE_JSON="$REPORT_DIR/subagent_compare_summary.json"
# Fallback to old filename for backward compatibility
[[ ! -f "$COMPARE_JSON" ]] && COMPARE_JSON="$REPORT_DIR/claude_compare_summary.json"
if [[ ! -f "$COMPARE_JSON" ]]; then
  log "❌ Compare JSON not found: $COMPARE_JSON"
  exit 1
fi
log "✅ Compare JSON created"

# Test 8: Verify compare JSON has timestamp
if command -v jq >/dev/null 2>&1; then
  if ! jq -e '.timestamp' "$COMPARE_JSON" >/dev/null 2>&1 && ! jq -e '.compare_timestamp' "$COMPARE_JSON" >/dev/null 2>&1; then
    log "❌ Compare JSON missing timestamp field"
    exit 1
  fi
  log "✅ Compare JSON has timestamp field"
else
  if ! grep -q '"timestamp"' "$COMPARE_JSON" && ! grep -q '"compare_timestamp"' "$COMPARE_JSON"; then
    log "❌ Compare JSON missing timestamp field (jq not available for validation)"
    exit 1
  fi
  log "✅ Compare JSON contains timestamp field (jq not available, basic check)"
fi

# Test 9: Verify metrics log was created
METRICS_LOG="$BASE/logs/subagent_metrics.log"
if [[ -f "$METRICS_LOG" ]]; then
  if ! grep -q "strategy=compete" "$METRICS_LOG"; then
    log "⚠️  Metrics log exists but doesn't contain expected entry"
  else
    log "✅ Metrics log contains expected entry"
  fi
else
  log "⚠️  Metrics log not found (may be created on first run)"
fi

log ""
log "✅ All smoke tests passed!"
exit 0
