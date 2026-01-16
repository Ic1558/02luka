#!/usr/bin/env zsh
# code_review_gate.zsh — Fast Code Review Gate for Auto Workflow
# 
# Purpose: Gate 2.5 in auto workflow (after DRYRUN, before VERIFY)
# - Style check, history-aware review, obvious-bug scan
# - Summarize risks + diff hotspots
# - One final verdict: ✅/⚠️ with reasons
#
# Uses catalog_lookup.zsh for tool discovery (no outdated info)
# Fast cached lookup to prevent lag

set -euo pipefail

LUKA_BASE="${LUKA_BASE:-$HOME/02luka}"
CACHE_DIR="$LUKA_BASE/g/.cache"
CACHE_FILE="$CACHE_DIR/code_review_cache.json"
CATALOG_LOOKUP="$LUKA_BASE/tools/catalog_lookup.zsh"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Ensure cache dir exists
mkdir -p "$CACHE_DIR"

# Lookup tools from catalog (single source of truth)
lookup_tool() {
    local tool="$1"
    if [[ -f "$CATALOG_LOOKUP" ]]; then
        zsh "$CATALOG_LOOKUP" "$tool" 2>/dev/null | grep -E "entry:|fallback:" | head -1 | sed 's/.*: //' | tr -d '"' || echo ""
    else
        echo ""
    fi
}

# Get review tool (from catalog)
get_review_tool() {
    local cached="$CACHE_DIR/review_tool.cache"
    
    # Check cache first (fast lookup)
    if [[ -f "$cached" ]] && [[ $(find "$cached" -mtime -1 2>/dev/null) ]]; then
        cat "$cached"
        return
    fi
    
    # Lookup from catalog
    local tool=$(lookup_tool "code-review")
    if [[ -z "$tool" ]]; then
        tool=$(lookup_tool "local_agent_review")
    fi
    
    # Fallback to known path
    if [[ -z "$tool" ]]; then
        tool="$LUKA_BASE/tools/local_agent_review.py"
    fi
    
    # Cache result
    echo "$tool" > "$cached"
    echo "$tool"
}

# Get git diff
get_diff() {
    local mode="${1:-staged}"
    
    case "$mode" in
        staged)
            git diff --cached
            ;;
        unstaged)
            git diff
            ;;
        all)
            git diff HEAD
            ;;
        *)
            git diff "$mode"
            ;;
    esac
}

# Quick style check (fast)
quick_style_check() {
    local diff_content="$1"
    local issues=0
    
    # Check for common style issues
    if echo "$diff_content" | grep -qE "^\+\s*[[:space:]]{1,}[^[:space:]]"; then
        echo "⚠️  Inconsistent indentation"
        ((issues++))
    fi
    
    if echo "$diff_content" | grep -qE "^\+\s*[[:space:]]*$"; then
        echo "⚠️  Trailing whitespace"
        ((issues++))
    fi
    
    if echo "$diff_content" | grep -qE "^\+\s*[^/]*//.*TODO|FIXME|HACK"; then
        echo "⚠️  TODO/FIXME/HACK comments"
        ((issues++))
    fi
    
    return $issues
}

# History-aware check (git blame)
history_aware_check() {
    local file="$1"
    local issues=0
    
    if [[ ! -f "$file" ]]; then
        return 0
    fi
    
    # Check if file has recent changes (potential churn)
    local recent_changes=$(git log --since="1 week ago" --oneline -- "$file" | wc -l | tr -d ' ')
    
    if [[ $recent_changes -gt 5 ]]; then
        echo "⚠️  High churn: $recent_changes changes in last week"
        ((issues++))
    fi
    
    return $issues
}

# Obvious bug scan
obvious_bug_scan() {
    local diff_content="$1"
    local issues=0
    
    # Common bug patterns
    if echo "$diff_content" | grep -qE "^\+\s*.*if\s*\([^)]*==\s*null|None\)"; then
        echo "⚠️  Potential null comparison bug"
        ((issues++))
    fi
    
    if echo "$diff_content" | grep -qE "^\+\s*.*\brm\s+-rf\s+/"; then
        echo "🚨 CRITICAL: Dangerous rm -rf / pattern"
        ((issues += 10))
    fi
    
    if echo "$diff_content" | grep -qE "^\+\s*.*password\s*=\s*['\"][^'\"]+['\"]"; then
        echo "🚨 CRITICAL: Hardcoded password"
        ((issues += 10))
    fi
    
    if echo "$diff_content" | grep -qE "^\+\s*.*eval\s*\("; then
        echo "⚠️  eval() usage (security risk)"
        ((issues++))
    fi
    
    return $issues
}

# Find diff hotspots (files with most changes)
find_hotspots() {
    local diff_content="$1"
    
    echo "$diff_content" | grep -E "^\+\+\+ b/" | sed 's/^\+\+\+ b\///' | \
    while read file; do
        local lines=$(echo "$diff_content" | grep -E "^\+.*" | grep -c "$file" || echo "0")
        echo "$lines $file"
    done | sort -rn | head -5 | awk '{print "  " $2 " (" $1 " lines)"}'
}

# Main review function
review_code() {
    local target="${1:-staged}"
    local quick_mode="${2:-false}"
    
    echo "${CYAN}🔍 Code Review Gate${NC}"
    echo "─────────────────────────────"
    
    # Get diff
    local diff_content=$(get_diff "$target")
    
    if [[ -z "$diff_content" ]]; then
        echo "${YELLOW}⚠️  No changes to review${NC}"
        echo "✅ VERDICT: No changes"
        return 0
    fi
    
    local total_issues=0
    local critical_issues=0
    local warnings=()
    
    # Quick style check
    echo "${CYAN}Style Check...${NC}"
    local style_issues=$(quick_style_check "$diff_content" 2>&1 || true)
    if [[ -n "$style_issues" ]]; then
        echo "$style_issues"
        warnings+=("Style issues found")
        ((total_issues++))
    fi
    
    # History-aware check (if not quick mode)
    if [[ "$quick_mode" != "true" ]]; then
        echo "${CYAN}History Check...${NC}"
        local files=$(echo "$diff_content" | grep -E "^\+\+\+ b/" | sed 's/^\+\+\+ b\///')
        while read file; do
            local hist_issues=$(history_aware_check "$file" 2>&1 || true)
            if [[ -n "$hist_issues" ]]; then
                echo "$hist_issues"
                warnings+=("High churn detected")
                ((total_issues++))
            fi
        done <<< "$files"
    fi
    
    # Obvious bug scan
    echo "${CYAN}Bug Scan...${NC}"
    local bug_issues=$(obvious_bug_scan "$diff_content" 2>&1 || true)
    if [[ -n "$bug_issues" ]]; then
        echo "$bug_issues"
        if echo "$bug_issues" | grep -q "🚨 CRITICAL"; then
            critical_issues=1
            warnings+=("CRITICAL issues found")
        else
            warnings+=("Potential bugs found")
        fi
        ((total_issues++))
    fi
    
    # Find hotspots
    echo "${CYAN}Diff Hotspots:${NC}"
    local hotspots=$(find_hotspots "$diff_content")
    if [[ -n "$hotspots" ]]; then
        echo "$hotspots"
    else
        echo "  (no significant hotspots)"
    fi
    
    # Final verdict
    echo ""
    echo "─────────────────────────────"
    
    if [[ $critical_issues -gt 0 ]]; then
        echo "${RED}⚠️  VERDICT: CRITICAL ISSUES FOUND${NC}"
        echo "   Reasons: ${warnings[*]}"
        return 1
    elif [[ $total_issues -gt 0 ]]; then
        echo "${YELLOW}⚠️  VERDICT: ISSUES FOUND${NC}"
        echo "   Reasons: ${warnings[*]}"
        return 1
    else
        echo "${GREEN}✅ VERDICT: PASS${NC}"
        echo "   No critical issues detected"
        return 0
    fi
}

# Main
case "${1:-}" in
    --help|-h)
        cat << EOF
Code Review Gate — Fast Review for Auto Workflow

USAGE:
    zsh code_review_gate.zsh [target] [--quick] [--json]

TARGET:
    staged      Review staged changes (default)
    unstaged    Review unstaged changes
    all         Review all changes
    <path>      Review specific file/path

FLAGS:
    --quick     Skip history-aware checks (faster)
    --json      Output as JSON

EXAMPLES:
    zsh code_review_gate.zsh staged
    zsh code_review_gate.zsh --quick
    zsh code_review_gate.zsh tools/my_script.zsh

OUTPUT:
    ✅ VERDICT: PASS — No issues
    ⚠️  VERDICT: ISSUES FOUND — Warnings
    ⚠️  VERDICT: CRITICAL ISSUES FOUND — Blocking issues

This tool uses catalog_lookup.zsh for tool discovery (single source of truth).
EOF
        exit 0
        ;;
    --quick)
        review_code "staged" "true"
        ;;
    --json)
        # JSON output mode
        review_code "staged" "false" | jq -R -s '{verdict: .}' 2>/dev/null || review_code "staged" "false"
        ;;
    "")
        review_code "staged"
        ;;
    *)
        review_code "$1"
        ;;
esac

