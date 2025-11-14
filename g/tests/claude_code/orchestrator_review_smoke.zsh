#!/usr/bin/env zsh
# Orchestrator Review Strategy Smoke Test
# Purpose: Test orchestrator "review strategy" with 2 agents
# Usage: orchestrator_review_smoke.zsh

set -euo pipefail

BASE="${LUKA_SOT:-$HOME/02luka}"
source "$BASE/tools/lib/check_runner.zsh"

echo "=== Smoke Test: Orchestrator Review Strategy ==="
echo ""

# Test 1: Orchestrator script exists
cr_run_check orchestrator_script_exists -- test -x "$BASE/tools/subagents/orchestrator.zsh"

# Test 2: Backend adapters exist
cr_run_check cls_adapter_exists -- test -f "$BASE/tools/subagents/adapters/cls.zsh"
cr_run_check claude_adapter_exists -- test -f "$BASE/tools/subagents/adapters/claude.zsh"

# Test 3: Run orchestrator with review strategy (2 agents)
# Use a simple test command
TEST_COMMAND="echo 'test from orchestrator'"
cr_run_check orchestrator_review_run -- BACKEND=cls "$BASE/tools/subagents/orchestrator.zsh" review "$TEST_COMMAND" 2

# Test 4: Orchestrator summary JSON exists
cr_run_check orchestrator_summary_exists -- test -f "$BASE/g/reports/system/subagent_orchestrator_summary.json"

# Test 5: Orchestrator summary has required fields
if [[ -f "$BASE/g/reports/system/subagent_orchestrator_summary.json" ]]; then
  if command -v jq >/dev/null 2>&1; then
    cr_run_check orchestrator_summary_valid -- jq -e '.backend != null and .strategy != null' "$BASE/g/reports/system/subagent_orchestrator_summary.json"
    
    # Test 6: Backend field is "cls"
    cr_run_check orchestrator_backend_cls -- jq -e '.backend == "cls"' "$BASE/g/reports/system/subagent_orchestrator_summary.json"
    
    # Test 7: Strategy field is "review"
    cr_run_check orchestrator_strategy_review -- jq -e '.strategy == "review"' "$BASE/g/reports/system/subagent_orchestrator_summary.json"
  else
    echo "⚠️  jq not available, skipping JSON validation"
  fi
fi

# Test 8: Compare results script can process orchestrator summary
if [[ -f "$BASE/g/reports/system/subagent_orchestrator_summary.json" ]]; then
  cr_run_check compare_results_run -- "$BASE/tools/subagents/compare_results.zsh"
fi

# Test 9: Compare results JSON exists
cr_run_check compare_results_json_exists -- test -f "$BASE/g/reports/system/subagent_compare_summary.json"

echo ""
echo "=== Test Complete ==="
echo ""
echo "Reports generated:"
echo "  - $CR_MD_PATH"
echo "  - $CR_JSON_PATH"

exit 0
