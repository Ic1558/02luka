#!/usr/bin/env bash
#
# CI Bot Command Handler
# Provides CLI interface for GitHub bot commands related to CI rebasing
#
# Usage:
#   ci_bot_commands.zsh [command] [options]
#
# Commands:
#   trigger-rebase [--pr NUM]       Trigger CI rebase via PR comment
#   check-status                    Check current CI PR status
#   dispatch [--mode MODE]          Dispatch workflow manually
#   help                            Show this help
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="${REPO:-Ic1558/02luka}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

log() {
  local color=$1; shift
  echo -e "${color}$@${NC}" >&2
}

need() {
  command -v "$1" >/dev/null 2>&1 || {
    log "$RED" "❌ Missing required tool: $1"
    exit 1
  }
}

show_help() {
  sed -n '2,/^$/p' "$0" | sed 's/^# //' | sed 's/^#//'
  exit 0
}

# Check prerequisites
need gh
need jq

# Verify authentication
if ! gh auth status >/dev/null 2>&1; then
  log "$RED" "❌ GitHub CLI not authenticated"
  log "$YELLOW" "Run: gh auth login"
  exit 1
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Commands
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

cmd_trigger_rebase() {
  local pr_num=""
  local only_failing=false

  while (( $# )); do
    case "$1" in
      --pr)
        pr_num="$2"
        shift
        ;;
      --only-failing)
        only_failing=true
        ;;
      *)
        log "$RED" "Unknown option: $1"
        exit 1
        ;;
    esac
    shift
  done

  # Auto-detect PR if in a branch
  if [[ -z "$pr_num" ]]; then
    local branch=$(git branch --show-current 2>/dev/null || echo "")
    if [[ -n "$branch" && "$branch" != "main" ]]; then
      pr_num=$(gh pr view "$branch" --json number --jq '.number' 2>/dev/null || echo "")
    fi
  fi

  if [[ -z "$pr_num" ]]; then
    log "$RED" "❌ No PR specified and couldn't auto-detect"
    log "$YELLOW" "Usage: $0 trigger-rebase --pr NUM"
    exit 1
  fi

  log "$CYAN" "🤖 Triggering CI rebase via bot command on PR #$pr_num..."

  # Build comment
  local comment="/rebase-ci"
  [[ "$only_failing" == "true" ]] && comment="$comment --only-failing"

  # Post comment
  if gh pr comment "$pr_num" --repo "$REPO" --body "$comment"; then
    log "$GREEN" "✅ Bot command posted to PR #$pr_num"
    log "$CYAN" "ℹ️  The workflow will start shortly. Monitor progress:"
    log "$CYAN" "   gh run watch --repo $REPO"
  else
    log "$RED" "❌ Failed to post comment"
    exit 1
  fi
}

cmd_check_status() {
  log "$CYAN" "🔍 Checking CI PR status..."
  echo ""

  # Run the report
  "$SCRIPT_DIR/global_ci_branches.zsh" --report --repo "$REPO"
}

cmd_dispatch() {
  local mode="report"
  local only_failing=false
  local force=false
  local base="origin/main"

  while (( $# )); do
    case "$1" in
      --mode)
        mode="$2"
        shift
        ;;
      --only-failing)
        only_failing=true
        ;;
      --force)
        force=true
        ;;
      --base)
        base="$2"
        shift
        ;;
      *)
        log "$RED" "Unknown option: $1"
        exit 1
        ;;
    esac
    shift
  done

  log "$CYAN" "🚀 Dispatching workflow..."
  log "$CYAN" "   Mode: $mode"
  log "$CYAN" "   Only failing: $only_failing"
  log "$CYAN" "   Force: $force"
  log "$CYAN" "   Base: $base"
  echo ""

  # Dispatch workflow
  gh workflow run ci-rebase-automation.yml \
    --repo "$REPO" \
    -f mode="$mode" \
    -f only_failing="$only_failing" \
    -f force="$force" \
    -f base_branch="$base"

  if [[ $? -eq 0 ]]; then
    log "$GREEN" "✅ Workflow dispatched successfully"
    log "$CYAN" "ℹ️  Monitor progress:"
    log "$CYAN" "   gh run watch --repo $REPO"
  else
    log "$RED" "❌ Failed to dispatch workflow"
    exit 1
  fi
}

cmd_list_workflows() {
  log "$CYAN" "📋 Recent CI Rebase Automation runs:"
  echo ""

  gh run list \
    --repo "$REPO" \
    --workflow "ci-rebase-automation.yml" \
    --limit 10
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Main
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CMD="${1:-help}"
shift || true

case "$CMD" in
  trigger-rebase|trigger)
    cmd_trigger_rebase "$@"
    ;;
  check-status|check|status)
    cmd_check_status "$@"
    ;;
  dispatch)
    cmd_dispatch "$@"
    ;;
  list|workflows)
    cmd_list_workflows "$@"
    ;;
  help|--help|-h)
    show_help
    ;;
  *)
    log "$RED" "❌ Unknown command: $CMD"
    echo ""
    show_help
    ;;
esac
