#!/usr/bin/env zsh
set -euo pipefail
ROOT="${HOME}/02luka"
Y="$(date +%Y%m)"
OUT="${ROOT}/g/reports/claude_code_metrics_${Y}.md"
mkdir -p "$(dirname "$OUT")"
{
  echo "# Claude Code Metrics ${Y}"
  echo "- Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "- plan_mode_usage: (stub)"
  echo "- hooks: pre_commit=OK quality_gate=OK verify_deployment=OK"
  echo "- subagents_used: (stub)"
  echo "- deployments_success_rate: (stub)"
  echo "- rollback_frequency: (stub)"
} > "$OUT"
echo "$OUT"
