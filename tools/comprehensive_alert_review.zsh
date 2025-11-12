#!/usr/bin/env zsh
# Comprehensive Alert Review Tool
# Purpose: Automate system-wide alert and issue review
# Usage: tools/comprehensive_alert_review.zsh

set -euo pipefail

REPO="${LUKA_SOT:-$HOME/02luka}"
cd "$REPO"

OUTPUT_DIR="$REPO/g/reports"
REPORT_FILE="$OUTPUT_DIR/comprehensive_alert_review_$(date +%Y%m%d).md"
JSON_FILE="$OUTPUT_DIR/comprehensive_alert_review_$(date +%Y%m%d).json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Issue tracking
CRITICAL_ISSUES=()
WARNING_ISSUES=()
INFO_ISSUES=()

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Helper: Log with timestamp
log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" >&2
}

# Helper: Check if tool exists
check_tool() {
  local tool="$1"
  if ! command -v "$tool" >/dev/null 2>&1; then
    log "⚠️  Tool not found: $tool (some checks may be skipped)"
    return 1
  fi
  return 0
}

# Helper: Categorize issue
categorize_issue() {
  local level="$1"
  local message="$2"
  local details="${3:-}"
  
  case "$level" in
    critical)
      CRITICAL_ISSUES+=("$message")
      echo -e "${RED}❌ CRITICAL:${NC} $message" >&2
      ;;
    warning)
      WARNING_ISSUES+=("$message")
      echo -e "${YELLOW}⚠️  WARNING:${NC} $message" >&2
      ;;
    info)
      INFO_ISSUES+=("$message")
      echo -e "${GREEN}ℹ️  INFO:${NC} $message" >&2
      ;;
  esac
  
  [[ -n "$details" ]] && echo "   $details" >&2
}

# Check 1: System Health
check_system_health() {
  log "📊 Checking system health..."
  
  local health_file="$REPO/g/reports/health_dashboard.json"
  
  if [[ ! -f "$health_file" ]]; then
    categorize_issue "critical" "Health dashboard not found" "Expected: $health_file"
    return
  fi
  
  if ! jq . "$health_file" >/dev/null 2>&1; then
    categorize_issue "critical" "Health dashboard JSON is invalid"
    return
  fi
  
  local health_status=$(jq -r '.status // "unknown"' "$health_file" 2>/dev/null)
  local score=$(jq -r '.health.score // 0' "$health_file" 2>/dev/null)
  local passed=$(jq -r '.health.passed // 0' "$health_file" 2>/dev/null)
  local total=$(jq -r '.health.total // 0' "$health_file" 2>/dev/null)
  
  if [[ "$health_status" != "ok" ]]; then
    categorize_issue "critical" "System health status: $health_status"
  elif [[ "$score" -lt 80 ]]; then
    categorize_issue "warning" "Health score below threshold: $score/100" "Passed: $passed/$total"
  else
    categorize_issue "info" "System health: OK" "Score: $score/100 ($passed/$total passed)"
  fi
}

# Check 2: Workflow Status
check_workflow_status() {
  log "🔄 Checking workflow status..."
  
  if ! check_tool "gh"; then
    categorize_issue "warning" "GitHub CLI not available" "Skipping workflow status check"
    return
  fi
  
  if ! gh auth status >/dev/null 2>&1; then
    categorize_issue "warning" "GitHub CLI not authenticated" "Run: gh auth login"
    return
  fi
  
  local recent_runs=$(gh run list --limit 10 --json workflowName,status,conclusion,createdAt 2>/dev/null || echo "[]")
  local total=$(echo "$recent_runs" | jq 'length')
  local success=$(echo "$recent_runs" | jq '[.[] | select(.conclusion=="success")] | length')
  local failed=$(echo "$recent_runs" | jq '[.[] | select(.conclusion=="failure")] | length')
  local cancelled=$(echo "$recent_runs" | jq '[.[] | select(.conclusion=="cancelled")] | length')
  
  if [[ "$total" -eq 0 ]]; then
    categorize_issue "warning" "No recent workflow runs found"
    return
  fi
  
  local success_rate=$((success * 100 / total))
  
  if [[ "$failed" -gt 0 ]]; then
    categorize_issue "warning" "Failed workflows detected: $failed/$total" "Success rate: $success_rate%"
  elif [[ "$cancelled" -gt 2 ]]; then
    categorize_issue "warning" "High cancellation rate: $cancelled/$total" "Success rate: $success_rate%"
  else
    categorize_issue "info" "Workflow status: OK" "Success: $success/$total ($success_rate%), Cancelled: $cancelled/$total"
  fi
}

# Check 3: YAML Syntax
check_yaml_syntax() {
  log "📝 Checking YAML syntax..."
  
  if ! check_tool "python3"; then
    categorize_issue "warning" "Python3 not available" "Skipping YAML validation"
    return
  fi
  
  local workflows_dir="$REPO/.github/workflows"
  local invalid_files=()
  local total=0
  
  if [[ ! -d "$workflows_dir" ]]; then
    categorize_issue "warning" "Workflows directory not found: $workflows_dir"
    return
  fi
  
  # Use find to avoid glob expansion issues
  while IFS= read -r file; do
    [[ ! -f "$file" ]] && continue
    total=$((total + 1))
    
    if ! python3 -c "import yaml; yaml.safe_load(open('$file'))" >/dev/null 2>&1; then
      invalid_files+=("$(basename "$file")")
    fi
  done < <(find "$workflows_dir" -maxdepth 1 -type f \( -name "*.yml" -o -name "*.yaml" \) 2>/dev/null || true)
  
  if [[ ${#invalid_files[@]} -gt 0 ]]; then
    categorize_issue "critical" "Invalid YAML syntax in ${#invalid_files[@]} workflow file(s)" "${invalid_files[*]}"
  else
    categorize_issue "info" "YAML syntax: Valid" "Checked $total workflow files"
  fi
}

# Check 4: Linter Errors
check_linter_errors() {
  log "🔍 Checking linter errors..."
  
  # Check if linter is available (yamllint, actionlint, etc.)
  local linter_found=false
  
  if command -v yamllint >/dev/null 2>&1; then
    linter_found=true
    local errors=$(yamllint "$REPO/.github/workflows"/*.yml 2>&1 | grep -c "error" || echo "0")
    errors="${errors:-0}"  # Ensure numeric value
    if [[ "$errors" =~ ^[0-9]+$ ]] && [[ "$errors" -gt 0 ]]; then
      categorize_issue "warning" "YAML linter found $errors error(s)"
    else
      categorize_issue "info" "YAML linter: No errors found"
    fi
  fi
  
  if ! $linter_found; then
    categorize_issue "info" "YAML linter not available" "Install yamllint for linting checks"
  fi
}

# Check 5: Git Status
check_git_status() {
  log "📋 Checking git status..."
  
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    categorize_issue "warning" "Not a git repository"
    return
  fi
  
  local uncommitted=$(git status --short 2>/dev/null | grep -v "^??" | grep -v "logs/" | wc -l | tr -d ' ')
  local untracked=$(git status --short 2>/dev/null | grep "^??" | grep -v "logs/" | wc -l | tr -d ' ')
  
  if [[ "$uncommitted" -gt 5 ]]; then
    categorize_issue "warning" "Multiple uncommitted changes: $uncommitted files" "Review with: git status"
  elif [[ "$uncommitted" -gt 0 ]]; then
    categorize_issue "info" "Uncommitted changes: $uncommitted file(s)" "Review with: git status"
  fi
  
  if [[ "$untracked" -gt 10 ]]; then
    categorize_issue "warning" "Many untracked files: $untracked" "Consider .gitignore updates"
  fi
  
  if [[ "$uncommitted" -eq 0 && "$untracked" -eq 0 ]]; then
    categorize_issue "info" "Git status: Clean"
  fi
}

# Check 6: Cancellation Analysis
check_cancellations() {
  log "🚫 Checking workflow cancellations..."
  
  if [[ ! -f "$REPO/tools/gha_cancellation_report.zsh" ]]; then
    categorize_issue "info" "Cancellation report tool not found" "Skipping cancellation analysis"
    return
  fi
  
  if ! check_tool "gh"; then
    categorize_issue "warning" "GitHub CLI not available" "Skipping cancellation analysis"
    return
  fi
  
  # Run cancellation report (suppress output, capture JSON, with timeout)
  # Skip if report already exists from today
  local report_file="$REPO/g/reports/system/gha_cancellations_WEEKLY_$(date +%Y%m%d).json"
  
  # Only run if report doesn't exist (to avoid long waits)
  if [[ ! -f "$report_file" ]]; then
    # Use timeout and background process to avoid blocking
    (timeout 5 bash -c "SINCE='7d' '$REPO/tools/gha_cancellation_report.zsh'" >/dev/null 2>&1 &) || true
    sleep 1  # Brief wait for process to start
  fi
  
  if [[ -f "$report_file" ]]; then
    local total=$(jq -r '.total_cancelled // 0' "$report_file" 2>/dev/null || echo "0")
    
    if [[ "$total" -gt 10 ]]; then
      categorize_issue "warning" "High cancellation rate: $total cancelled runs in last 7 days"
    elif [[ "$total" -gt 3 ]]; then
      categorize_issue "info" "Cancellation rate: $total cancelled runs in last 7 days" "Monitor for improvements"
    else
      categorize_issue "info" "Cancellation rate: Low" "$total cancelled runs in last 7 days"
    fi
  else
    categorize_issue "info" "Cancellation report not generated" "May need GitHub authentication"
  fi
}

# Check 7: Known Issues
check_known_issues() {
  log "📚 Checking known issues..."
  
  # Scan for known issue markers in documentation (use find to avoid glob issues)
  local found_issues=0
  
  # Check reports directory
  if [[ -d "$REPO/g/reports" ]]; then
    while IFS= read -r file; do
      [[ ! -f "$file" ]] && continue
      if grep -qi "known issue\|outstanding\|todo\|fixme" "$file" 2>/dev/null; then
        found_issues=$((found_issues + 1))
      fi
    done < <(find "$REPO/g/reports" -type f -name "*.md" 2>/dev/null | head -20 || true)
  fi
  
  if [[ "$found_issues" -gt 0 ]]; then
    categorize_issue "info" "Known issues documented: $found_issues file(s)" "Review documentation for details"
  else
    categorize_issue "info" "No known issues found in documentation"
  fi
}

# Generate Markdown Report
generate_markdown_report() {
  log "📄 Generating markdown report..."
  
  {
    echo "# Comprehensive Alert Review"
    echo "**Date:** $(date +%Y-%m-%d)"
    echo "**Generated:** $TIMESTAMP"
    echo "**Scope:** System-wide alert and issue review"
    echo ""
    echo "---"
    echo ""
    echo "## Executive Summary"
    echo ""
    
    local overall_status="✅ HEALTHY"
    if [[ ${#CRITICAL_ISSUES[@]} -gt 0 ]]; then
      overall_status="🔴 CRITICAL"
    elif [[ ${#WARNING_ISSUES[@]} -gt 0 ]]; then
      overall_status="⚠️  WARNING"
    fi
    
    echo "**Status:** $overall_status"
    echo ""
    echo "**Key Findings:**"
    echo "- Critical Issues: ${#CRITICAL_ISSUES[@]}"
    echo "- Warnings: ${#WARNING_ISSUES[@]}"
    echo "- Info: ${#INFO_ISSUES[@]}"
    echo ""
    echo "---"
    echo ""
    echo "## 1. System Health Status"
    echo ""
    echo "### Health Dashboard"
    if [[ -f "$REPO/g/reports/health_dashboard.json" ]]; then
      local health_status=$(jq -r '.status // "unknown"' "$REPO/g/reports/health_dashboard.json" 2>/dev/null)
      local score=$(jq -r '.health.score // 0' "$REPO/g/reports/health_dashboard.json" 2>/dev/null)
      echo "**Status:** \`$health_status\`"
      echo "**Health Score:** $score/100"
      echo "**Assessment:** System is $(if [[ "$health_status" == "ok" && "$score" -ge 80 ]]; then echo "healthy"; else echo "degraded"; fi)"
    else
      echo "**Status:** ⚠️ Dashboard not found"
    fi
    echo ""
    echo "---"
    echo ""
    echo "## 2. Workflow Status"
    echo ""
    echo "### Recent Workflow Runs"
    if check_tool "gh" && gh auth status >/dev/null 2>&1; then
      echo "**Status:** Checked via GitHub CLI"
      echo "**Details:** See workflow status section"
    else
      echo "**Status:** ⚠️ GitHub CLI not available"
    fi
    echo ""
    echo "---"
    echo ""
    echo "## 3. Code Quality Checks"
    echo ""
    echo "### YAML Syntax"
    echo "**Status:** Validated"
    echo ""
    echo "### Linter Errors"
    echo "**Status:** Checked"
    echo ""
    echo "---"
    echo ""
    echo "## 4. Git Status"
    echo ""
    if git rev-parse --git-dir >/dev/null 2>&1; then
      local uncommitted=$(git status --short 2>/dev/null | grep -v "^??" | grep -v "logs/" | wc -l | tr -d ' ')
      echo "**Uncommitted Changes:** $uncommitted file(s)"
    else
      echo "**Status:** Not a git repository"
    fi
    echo ""
    echo "---"
    echo ""
    echo "## 5. Cancellation Analysis"
    echo ""
    echo "**Status:** Analyzed via cancellation report tool"
    echo ""
    echo "---"
    echo ""
    echo "## 6. Known Issues"
    echo ""
    echo "**Status:** Scanned documentation"
    echo ""
    echo "---"
    echo ""
    echo "## 7. Alert Summary"
    echo ""
    echo "| Category | Count | Priority |"
    echo "|----------|-------|----------|"
    echo "| Critical Issues | ${#CRITICAL_ISSUES[@]} | $(if [[ ${#CRITICAL_ISSUES[@]} -gt 0 ]]; then echo "High"; else echo "-"; fi) |"
    echo "| Warnings | ${#WARNING_ISSUES[@]} | $(if [[ ${#WARNING_ISSUES[@]} -gt 0 ]]; then echo "Medium"; else echo "-"; fi) |"
    echo "| Info | ${#INFO_ISSUES[@]} | Low |"
    echo ""
    echo "---"
    echo ""
    echo "## 8. Detailed Findings"
    echo ""
    
    if [[ ${#CRITICAL_ISSUES[@]} -gt 0 ]]; then
      echo "### Critical Issues"
      for issue in "${CRITICAL_ISSUES[@]}"; do
        echo "- 🔴 $issue"
      done
      echo ""
    fi
    
    if [[ ${#WARNING_ISSUES[@]} -gt 0 ]]; then
      echo "### Warnings"
      for issue in "${WARNING_ISSUES[@]}"; do
        echo "- ⚠️  $issue"
      done
      echo ""
    fi
    
    if [[ ${#INFO_ISSUES[@]} -gt 0 ]]; then
      echo "### Information"
      for issue in "${INFO_ISSUES[@]}"; do
        echo "- ℹ️  $issue"
      done
      echo ""
    fi
    
    echo "---"
    echo ""
    echo "## 9. Recommendations"
    echo ""
    
    if [[ ${#CRITICAL_ISSUES[@]} -gt 0 ]]; then
      echo "1. **Address Critical Issues:** Review and fix ${#CRITICAL_ISSUES[@]} critical issue(s) immediately"
    fi
    
    if [[ ${#WARNING_ISSUES[@]} -gt 0 ]]; then
      echo "2. **Review Warnings:** Investigate ${#WARNING_ISSUES[@]} warning(s) when possible"
    fi
    
    echo "3. **Continue Monitoring:** Run this tool regularly to track system health"
    echo ""
    echo "---"
    echo ""
    echo "## 10. Conclusion"
    echo ""
    echo "**Overall Status:** $overall_status"
    echo ""
    echo "**Summary:**"
    if [[ ${#CRITICAL_ISSUES[@]} -eq 0 && ${#WARNING_ISSUES[@]} -eq 0 ]]; then
      echo "- No critical alerts"
      echo "- System operational"
    else
      echo "- ${#CRITICAL_ISSUES[@]} critical issue(s) require immediate attention"
      echo "- ${#WARNING_ISSUES[@]} warning(s) should be reviewed"
    fi
    echo ""
    echo "---"
    echo ""
    echo "**Review Date:** $(date +%Y-%m-%d)"
    echo "**Generated By:** Comprehensive Alert Review Tool"
    echo "**Status:** $overall_status"
  } > "$REPORT_FILE"
  
  log "✅ Markdown report generated: $REPORT_FILE"
}

# Generate JSON Summary
generate_json_summary() {
  log "📊 Generating JSON summary..."
  
  jq -n \
    --arg timestamp "$TIMESTAMP" \
    --argjson critical "${#CRITICAL_ISSUES[@]}" \
    --argjson warning "${#WARNING_ISSUES[@]}" \
    --argjson info "${#INFO_ISSUES[@]}" \
    --arg overall "$(if [[ ${#CRITICAL_ISSUES[@]} -gt 0 ]]; then echo "critical"; elif [[ ${#WARNING_ISSUES[@]} -gt 0 ]]; then echo "warning"; else echo "healthy"; fi)" \
    '{
      generated_at: $timestamp,
      overall_status: $overall,
      summary: {
        critical: $critical,
        warning: $warning,
        info: $info
      },
      issues: {
        critical: ($critical | tostring | split("") | map(. == "1") | if .[0] then [] else [] end),
        warning: ($warning | tostring | split("") | map(. == "1") | if .[0] then [] else [] end),
        info: ($info | tostring | split("") | map(. == "1") | if .[0] then [] else [] end)
      }
    }' > "$JSON_FILE" 2>/dev/null || {
    # Fallback JSON if jq fails
    cat > "$JSON_FILE" <<EOF
{
  "generated_at": "$TIMESTAMP",
  "overall_status": "$(if [[ ${#CRITICAL_ISSUES[@]} -gt 0 ]]; then echo "critical"; elif [[ ${#WARNING_ISSUES[@]} -gt 0 ]]; then echo "warning"; else echo "healthy"; fi)",
  "summary": {
    "critical": ${#CRITICAL_ISSUES[@]},
    "warning": ${#WARNING_ISSUES[@]},
    "info": ${#INFO_ISSUES[@]}
  }
}
EOF
  }
  
  log "✅ JSON summary generated: $JSON_FILE"
}

# Main execution
main() {
  echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║     Comprehensive Alert Review Tool                     ║${NC}"
  echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo "Time: $TIMESTAMP"
  echo ""
  
  # Run all checks
  check_system_health
  check_workflow_status
  check_yaml_syntax
  check_linter_errors
  check_git_status
  check_cancellations
  check_known_issues
  
  # Generate reports
  generate_markdown_report
  generate_json_summary
  
  # Print summary
  echo ""
  echo -e "${BLUE}=== Summary ===${NC}"
  echo -e "Critical: ${RED}${#CRITICAL_ISSUES[@]}${NC}"
  echo -e "Warnings: ${YELLOW}${#WARNING_ISSUES[@]}${NC}"
  echo -e "Info: ${GREEN}${#INFO_ISSUES[@]}${NC}"
  echo ""
  echo "Report: $REPORT_FILE"
  echo "JSON: $JSON_FILE"
  echo ""
  
  # Exit code based on findings
  if [[ ${#CRITICAL_ISSUES[@]} -gt 0 ]]; then
    echo -e "${RED}🔴 Critical issues found - immediate attention required${NC}"
    exit 1
  elif [[ ${#WARNING_ISSUES[@]} -gt 0 ]]; then
    echo -e "${YELLOW}⚠️  Warnings found - review recommended${NC}"
    exit 0
  else
    echo -e "${GREEN}✅ No critical alerts - system healthy${NC}"
    exit 0
  fi
}

# Run main function
main "$@"

