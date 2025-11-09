#!/usr/bin/env zsh
# PR Group Scanner - Group and sort PRs by various criteria
# Classification: Strategic Integration Patch (SIP)
# System: 02LUKA Cognitive Architecture
# Phase: 21.4 – PR Management
# Status: Active
# Maintainer: GG Core (02LUKA Automation)
# Version: v1.0.0

set -euo pipefail

REPO="${1:-Ic1558/02luka}"
GROUP_BY="${2:-phase}"  # phase, status, feature, date, mergeable

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[group]${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}[group]${NC} ✓ $*" >&2
}

log_warn() {
    echo -e "${YELLOW}[group]${NC} ⚠ $*" >&2
}

log_error() {
    echo -e "${RED}[group]${NC} ✗ $*" >&2
}

require() {
    command -v "$1" >/dev/null 2>&1 || {
        log_error "Missing required tool: $1"
        exit 1
    }
}

require gh
require jq

log_info "Fetching open PRs from $REPO..."

PRS_JSON=$(gh pr list --repo "$REPO" --state open --limit 100 --json number,title,headRefName,createdAt,updatedAt,mergeable,labels,author 2>/dev/null || echo "[]")

if [[ -z "$PRS_JSON" || "$PRS_JSON" == "[]" ]]; then
    log_warn "No open PRs found"
    exit 0
fi

# Group PRs by criteria
case "$GROUP_BY" in
    phase)
        log_info "Grouping PRs by Phase..."
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📊 PRs Grouped by Phase"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        
        # Extract phase from branch name or title
        echo "$PRS_JSON" | jq -r '.[] | "\(.number)|\(.title)|\(.headRefName)|\(.mergeable)"' | while IFS='|' read -r num title branch mergeable; do
            phase=""
            if echo "$branch" | grep -qE 'phase-([0-9]+)'; then
                phase=$(echo "$branch" | grep -oE 'phase-([0-9]+)' | head -1)
            elif echo "$title" | grep -qE 'Phase ([0-9]+)'; then
                phase=$(echo "$title" | grep -oE 'Phase ([0-9]+)' | head -1 | tr ' ' '-')
            else
                phase="other"
            fi
            
            status_icon=""
            if [[ "$mergeable" == "MERGEABLE" ]]; then
                status_icon="✅"
            elif [[ "$mergeable" == "CONFLICTING" ]]; then
                status_icon="⚠️"
            else
                status_icon="❓"
            fi
            
            echo "$phase|$num|$title|$status_icon"
        done | sort -t'|' -k1,1 | awk -F'|' '
        BEGIN { current_group = "" }
        {
            if ($1 != current_group) {
                if (current_group != "") print ""
                print "📦 " toupper($1)
                print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                current_group = $1
            }
            printf "  %s PR #%s: %s\n", $4, $2, $3
        }
        '
        ;;
    
    status)
        log_info "Grouping PRs by Merge Status..."
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📊 PRs Grouped by Merge Status"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        
        echo "$PRS_JSON" | jq -r '.[] | "\(.mergeable)|\(.number)|\(.title)"' | sort -t'|' -k1,1 | awk -F'|' '
        BEGIN { current_status = "" }
        {
            if ($1 != current_status) {
                if (current_status != "") print ""
                status_name = $1
                if (status_name == "MERGEABLE") {
                    print "✅ MERGEABLE"
                } else if (status_name == "CONFLICTING") {
                    print "⚠️  CONFLICTING"
                } else {
                    print "❓ " status_name
                }
                print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                current_status = $1
            }
            printf "  PR #%s: %s\n", $2, $3
        }
        '
        ;;
    
    feature)
        log_info "Grouping PRs by Feature..."
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📊 PRs Grouped by Feature"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        
        echo "$PRS_JSON" | jq -r '.[] | "\(.number)|\(.title)|\(.headRefName)|\(.mergeable)"' | while IFS='|' read -r num title branch mergeable; do
            feature="other"
            if echo "$title" | grep -qiE '(hub|dashboard|ui)'; then
                feature="hub"
            elif echo "$title" | grep -qiE '(ci|workflow|pipeline)'; then
                feature="ci"
            elif echo "$title" | grep -qiE '(ocr|validation|telemetry)'; then
                feature="ocr"
            elif echo "$title" | grep -qiE '(router|akr|routing)'; then
                feature="router"
            elif echo "$title" | grep -qiE '(agent|heartbeat|monitoring)'; then
                feature="monitoring"
            elif echo "$title" | grep -qiE '(web|app|frontend|react)'; then
                feature="webapp"
            elif echo "$title" | grep -qiE '(fix|bug|patch)'; then
                feature="fixes"
            elif echo "$title" | grep -qiE '(security|auth|protect)'; then
                feature="security"
            fi
            
            status_icon=""
            if [[ "$mergeable" == "MERGEABLE" ]]; then
                status_icon="✅"
            elif [[ "$mergeable" == "CONFLICTING" ]]; then
                status_icon="⚠️"
            else
                status_icon="❓"
            fi
            
            echo "$feature|$num|$title|$status_icon"
        done | sort -t'|' -k1,1 | awk -F'|' '
        BEGIN { current_group = "" }
        {
            if ($1 != current_group) {
                if (current_group != "") print ""
                group_name = toupper($1)
                gsub(/^./, toupper(substr($1,1,1)), group_name)
                print "📦 " group_name
                print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                current_group = $1
            }
            printf "  %s PR #%s: %s\n", $4, $2, $3
        }
        '
        ;;
    
    date)
        log_info "Grouping PRs by Date..."
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📊 PRs Grouped by Creation Date"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        
        echo "$PRS_JSON" | jq -r '.[] | "\(.createdAt)|\(.number)|\(.title)|\(.mergeable)"' | sort -t'|' -k1,1r | awk -F'|' '
        BEGIN { current_date = "" }
        {
            date_str = $1
            gsub(/T.*/, "", date_str)
            if (date_str != current_date) {
                if (current_date != "") print ""
                print "📅 " date_str
                print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                current_date = date_str
            }
            status_icon = ($4 == "MERGEABLE") ? "✅" : (($4 == "CONFLICTING") ? "⚠️" : "❓")
            printf "  %s PR #%s: %s\n", status_icon, $2, $3
        }
        '
        ;;
    
    mergeable)
        log_info "Grouping PRs by Mergeability..."
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📊 PRs Grouped by Mergeability"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        
        # MERGEABLE first
        echo "✅ MERGEABLE PRs"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "$PRS_JSON" | jq -r '.[] | select(.mergeable == "MERGEABLE") | "  PR #\(.number): \(.title)"'
        
        echo ""
        echo "⚠️  CONFLICTING PRs"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "$PRS_JSON" | jq -r '.[] | select(.mergeable == "CONFLICTING") | "  PR #\(.number): \(.title)"'
        
        echo ""
        echo "❓ UNKNOWN/OTHER PRs"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "$PRS_JSON" | jq -r '.[] | select(.mergeable != "MERGEABLE" and .mergeable != "CONFLICTING") | "  PR #\(.number): \(.title)"'
        ;;
    
    *)
        log_error "Unknown group_by option: $GROUP_BY"
        echo "Usage: $0 [REPO] [group_by]"
        echo ""
        echo "Group by options:"
        echo "  phase      - Group by Phase (phase-20, phase-21, etc.)"
        echo "  status     - Group by merge status (MERGEABLE, CONFLICTING)"
        echo "  feature    - Group by feature (hub, ci, ocr, router, etc.)"
        echo "  date       - Group by creation date"
        echo "  mergeable  - Group by mergeability (MERGEABLE first)"
        exit 1
        ;;
esac

echo ""
log_success "PR grouping complete"
