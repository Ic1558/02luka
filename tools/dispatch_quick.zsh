#!/usr/bin/env zsh
# Quick Dispatch Tool
# Provides shortcuts for common CI and monitoring operations

set -eo pipefail

SCRIPT_DIR="${0:A:h}"
ROOT="${ROOT:-$HOME/02luka}"

usage() {
  cat <<EOF
Usage: dispatch_quick.zsh <command> [args...]

Available commands:
  ci:ocr:telemetry    Show OCR SHA256 failure telemetry
  ci:rerun <PR#>      Re-run CI checks for a PR (uses gh CLI)
  ci:checks <PR#>     Show CI checks status for a PR
  help                Show this help message

EOF
  exit 0
}

case "${1:-help}" in
  ci:ocr:telemetry)
    exec "$SCRIPT_DIR/ocr_telemetry.zsh"
    ;;

  ci:rerun)
    PR="${2:-}"
    if [[ -z "$PR" ]]; then
      echo "❌ Usage: ci:rerun <PR_NUMBER>" >&2
      exit 1
    fi
    echo "♻️  Re-running CI checks for PR #$PR..."
    # Get the latest run ID for this PR
    RUN_ID=$(gh run list --workflow=ci --limit 1 --json databaseId,headBranch --jq ".[] | select(.headBranch | contains(\"$(gh pr view $PR --json headRefName -q .headRefName)\")) | .databaseId" 2>/dev/null | head -1)
    if [[ -n "$RUN_ID" ]]; then
      gh run rerun "$RUN_ID" && echo "✅ CI rerun triggered: https://github.com/Ic1558/02luka/actions/runs/$RUN_ID"
    else
      echo "⚠️  No recent CI run found. Triggering new run..."
      gh workflow run ci --ref "$(gh pr view $PR --json headRefName -q .headRefName)"
    fi
    ;;

  ci:checks)
    PR="${2:-}"
    if [[ -z "$PR" ]]; then
      echo "❌ Usage: ci:checks <PR_NUMBER>" >&2
      exit 1
    fi
    gh pr checks "$PR"
    ;;

  help|--help|-h)
    usage
    ;;

  *)
    echo "❌ Unknown command: $1" >&2
    echo ""
    usage
    exit 1
    ;;
esac
