#!/usr/bin/env zsh
# E2E Smoke Test for Claude Code Commands
# Purpose: Test all 5 slash commands
# Usage: e2e_smoke_commands.zsh

set -euo pipefail

BASE="${LUKA_SOT:-$HOME/02luka}"
source "$BASE/tools/lib/check_runner.zsh"

echo "=== E2E Smoke Test: Claude Code Commands ==="
echo ""

# Test 1: /feature-dev command file exists
cr_run_check feature_dev_command_exists -- test -f "$BASE/.claude/commands/feature-dev.md"

# Test 2: /code-review command file exists
cr_run_check code_review_command_exists -- test -f "$BASE/.claude/commands/code-review.md"

# Test 3: /deploy command file exists
cr_run_check deploy_command_exists -- test -f "$BASE/.claude/commands/deploy.md"

# Test 4: /commit command file exists
cr_run_check commit_command_exists -- test -f "$BASE/.claude/commands/commit.md"

# Test 5: /health-check command file exists
cr_run_check health_check_command_exists -- test -f "$BASE/.claude/commands/health-check.md"

# Test 6: Orchestrator script exists and is executable
cr_run_check orchestrator_exists -- test -x "$BASE/tools/subagents/orchestrator.zsh"

# Test 7: Compare results script exists and is executable
cr_run_check compare_results_exists -- test -x "$BASE/tools/subagents/compare_results.zsh"

# Test 8: Pre-commit hook exists and is executable
cr_run_check pre_commit_hook_exists -- test -x "$BASE/tools/claude_hooks/pre_commit.zsh"

# Test 9: Quality gate hook exists and is executable
cr_run_check quality_gate_hook_exists -- test -x "$BASE/tools/claude_hooks/quality_gate.zsh"

# Test 10: Verify deployment hook exists and is executable
cr_run_check verify_deployment_hook_exists -- test -x "$BASE/tools/claude_hooks/verify_deployment.zsh"

# Test 11: MLS capture tool exists and is executable
cr_run_check mls_capture_exists -- test -x "$BASE/tools/mls_capture.zsh"

# Test 12: Metrics collector exists (optional)
cr_run_check metrics_collector_exists -- test -x "$BASE/tools/claude_tools/metrics_collector.zsh" || true

# Test 13: Metrics to JSON exists
cr_run_check metrics_to_json_exists -- test -x "$BASE/tools/claude_tools/metrics_to_json.zsh"

# Test 14: Dashboard HTML exists
cr_run_check dashboard_html_exists -- test -f "$BASE/g/apps/dashboard/claude_code.html"

echo ""
echo "=== Test Complete ==="
echo ""
echo "Reports generated:"
echo "  - $CR_MD_PATH"
echo "  - $CR_JSON_PATH"

exit 0
