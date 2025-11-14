#!/usr/bin/env zsh
# PR Automation Helper - Main Interface
# Usage: ./pr-helper.zsh [command] [args]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

show_help() {
    cat << 'HELP'
PR Automation Helper

Usage: ./pr-helper.zsh [command] [args]

Commands:
  create [branch] [title]    Create a new PR from current/specified branch
  status [pr-number]         Check status of PR and workflows  
  fix                        Auto-retry failed workflows
  list                       List all open PRs
  merge [pr-number]          Merge a PR (with checks)
  close [pr-number]          Close a PR
  
  workflows                  List recent workflow runs
  notifications              Check GitHub notifications
  health                     Check repository health

Examples:
  ./pr-helper.zsh create                     # Create PR from current branch
  ./pr-helper.zsh create feat/new-feature "Add new feature"
  ./pr-helper.zsh status 123                 # Check PR #123 status
  ./pr-helper.zsh fix                        # Retry failed workflows
  ./pr-helper.zsh merge 123                  # Merge PR #123
  
Environment Variables:
  AUTO_RETRY=yes            Auto-retry failed workflows without asking
  OPEN_BROWSER=no           Don't auto-open PR in browser
  
HELP
}

CMD=${1:-help}
shift || true

case "$CMD" in
    create)
        "$SCRIPT_DIR/create-pr.zsh" "$@"
        ;;
    
    status)
        "$SCRIPT_DIR/check-pr-status.zsh" "$@"
        ;;
    
    fix)
        "$SCRIPT_DIR/fix-failed-workflows.zsh" "$@"
        ;;
    
    list)
        log $YELLOW "📋 Open Pull Requests:"
        gh pr list --repo "Ic1558/02luka" --state open
        ;;
    
    merge)
        PR_NUM=$1
        if [[ -z "$PR_NUM" ]]; then
            log $RED "❌ Error: PR number required"
            log $YELLOW "Usage: ./pr-helper.zsh merge [pr-number]"
            exit 1
        fi
        
        log $YELLOW "🔍 Checking PR #$PR_NUM before merge..."
        
        # Check if PR is mergeable
        MERGEABLE=$(gh pr view "$PR_NUM" --repo "Ic1558/02luka" --json mergeable --jq '.mergeable')
        if [[ "$MERGEABLE" != "MERGEABLE" ]]; then
            log $RED "❌ PR is not mergeable (conflicts or checks failing)"
            exit 1
        fi
        
        log $GREEN "✅ PR is mergeable"
        log $YELLOW "🔀 Merging PR #$PR_NUM..."
        
        gh pr merge "$PR_NUM" --repo "Ic1558/02luka" --squash --delete-branch
        log $GREEN "✅ PR merged and branch deleted"
        ;;
    
    close)
        PR_NUM=$1
        if [[ -z "$PR_NUM" ]]; then
            log $RED "❌ Error: PR number required"
            exit 1
        fi
        
        gh pr close "$PR_NUM" --repo "Ic1558/02luka"
        log $GREEN "✅ PR #$PR_NUM closed"
        ;;
    
    workflows)
        log $YELLOW "⚙️  Recent Workflow Runs:"
        gh run list --repo "Ic1558/02luka" --limit 20
        ;;
    
    notifications)
        log $YELLOW "🔔 Recent notifications:"
        gh api notifications | jq -r '.[] | "\(.subject.type): \(.subject.title) [\(.reason)]"' | head -20
        ;;
    
    health)
        log $YELLOW "🏥 Repository Health Check:"
        echo ""
        
        log $BLUE "📊 Open Issues:"
        gh issue list --repo "Ic1558/02luka" --limit 5
        echo ""
        
        log $BLUE "🔄 Open PRs:"
        gh pr list --repo "Ic1558/02luka" --state open
        echo ""
        
        log $BLUE "❌ Recent Failed Workflows:"
        gh run list --repo "Ic1558/02luka" --status failure --limit 5
        ;;
    
    help|--help|-h)
        show_help
        ;;
    
    *)
        log $RED "❌ Unknown command: $CMD"
        echo ""
        show_help
        exit 1
        ;;
esac
