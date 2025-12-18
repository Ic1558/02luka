#!/usr/bin/env zsh
# Comprehensive Alert Review Tool
# Purpose: Automate system-wide alert and issue review
# Usage: tools/comprehensive_alert_review.zsh

set -euo pipefail

REPO="${LUKA_SOT:-$HOME/02luka}"
cd "$REPO"

# Load check runner library (disable exit on error temporarily)
set +e
source "$REPO/tools/lib/check_runner.zsh"
set -e

OUTPUT_DIR="$REPO/g/reports"
REPORT_FILE="$OUTPUT_DIR/comprehensive_alert_review_$(date +%Y%m%d).md"
JSON_FILE="$OUTPUT_DIR/comprehensive_alert_review_$(date +%Y%m%d).json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Issue tracking (for backward compatibility with existing report format)
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

# Helper: Categorize issue (for backward compatibility)
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

# Main execution
main() {
  echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║     Comprehensive Alert Review Tool                     ║${NC}"
  echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo "Time: $TIMESTAMP"
  echo ""
  
  log "🔍 Running comprehensive system checks..."
  
  # Run all checks using check_runner library
  # Each check is isolated and won't cause early exit
  
  # Check 1: System Health
  cr_run_check system_health -- bash -c "
    health_file='$REPO/g/reports/health_dashboard.json'
    if [[ ! -f \"\$health_file\" ]]; then
      echo 'Health dashboard not found'
      exit 1
    fi
    if ! jq . \"\$health_file\" >/dev/null 2>&1; then
      echo 'Health dashboard JSON is invalid'
      exit 1
    fi
    status=\$(jq -r '.status // \"unknown\"' \"\$health_file\" 2>/dev/null)
    score=\$(jq -r '.health.score // 0' \"\$health_file\" 2>/dev/null)
    if [[ \"\$status\" != \"ok\" ]] || [[ \"\$score\" -lt 80 ]]; then
      echo \"Health status: \$status, score: \$score\"
      exit 1
    fi
    echo \"System health: OK (score: \$score/100)\"
  "
  
  # Check 2: Workflow Status
  if check_tool "gh" && gh auth status >/dev/null 2>&1; then
    cr_run_check workflow_status -- bash -c "
      recent_runs=\$(gh run list --limit 10 --json workflowName,status,conclusion,createdAt 2>/dev/null || echo '[]')
      total=\$(echo \"\$recent_runs\" | jq 'length')
      success=\$(echo \"\$recent_runs\" | jq '[.[] | select(.conclusion==\"success\")] | length')
      failed=\$(echo \"\$recent_runs\" | jq '[.[] | select(.conclusion==\"failure\")] | length')
      if [[ \"\$total\" -eq 0 ]]; then
        echo 'No recent workflow runs found'
        exit 1
      fi
      success_rate=\$((success * 100 / total))
      if [[ \"\$failed\" -gt 0 ]] || [[ \"\$success_rate\" -lt 70 ]]; then
        echo \"Workflow issues: \$failed failed, \$success_rate% success rate\"
        exit 1
      fi
      echo \"Workflow status: OK (\$success/\$total successful, \$success_rate%)\"
    "
  else
    cr_run_check workflow_status -- bash -c "echo 'GitHub CLI not available or not authenticated'; exit 1"
  fi
  
  # Check 3: YAML Syntax
  if check_tool "python3"; then
    cr_run_check yaml_syntax -- bash -c "
      workflows_dir='$REPO/.github/workflows'
      invalid=0
      total=0
      for file in \$(find \"\$workflows_dir\" -maxdepth 1 -type f \\( -name '*.yml' -o -name '*.yaml' \\) 2>/dev/null); do
        total=\$((total + 1))
        if ! python3 -c \"import yaml; yaml.safe_load(open('\$file'))\" >/dev/null 2>&1; then
          invalid=\$((invalid + 1))
        fi
      done
      if [[ \$invalid -gt 0 ]]; then
        echo \"Invalid YAML syntax in \$invalid/\$total workflow file(s)\"
        exit 1
      fi
      echo \"YAML syntax: Valid (checked \$total workflow files)\"
    "
  else
    cr_run_check yaml_syntax -- bash -c "echo 'Python3 not available'; exit 1"
  fi
  
  # Check 4: Linter Errors
  if check_tool "yamllint"; then
    cr_run_check linter_errors -- bash -c "
      errors=\$(yamllint \"$REPO/.github/workflows\"/*.yml 2>&1 | grep -c 'error' || echo '0')
      if [[ \"\$errors\" -gt 0 ]]; then
        echo \"YAML linter found \$errors error(s)\"
        exit 1
      fi
      echo 'YAML linter: No errors found'
    "
  else
    cr_run_check linter_errors -- bash -c "echo 'YAML linter not available'; exit 0"
  fi
  
  # Check 5: Git Status
  if git rev-parse --git-dir >/dev/null 2>&1; then
    cr_run_check git_status -- bash -c "
      uncommitted=\$(git status --short 2>/dev/null | grep -v '^??' | grep -v 'logs/' | wc -l | tr -d ' ' || echo '0')
      untracked=\$(git status --short 2>/dev/null | grep '^??' | grep -v 'logs/' | wc -l | tr -d ' ' || echo '0')
      if [[ \"\$uncommitted\" -gt 5 ]] || [[ \"\$untracked\" -gt 10 ]]; then
        echo \"Multiple uncommitted changes: \$uncommitted files, \$untracked untracked\"
        exit 1
      fi
      echo \"Git status: OK (\$uncommitted uncommitted, \$untracked untracked)\"
    "
  else
    cr_run_check git_status -- bash -c "echo 'Not a git repository'; exit 1"
  fi
  
  # Check 6: Cancellation Analysis
  if [[ -f "$REPO/tools/gha_cancellation_report.zsh" ]] && check_tool "gh"; then
    cr_run_check cancellations -- bash -c "
      report_file='$REPO/g/reports/system/gha_cancellations_WEEKLY_\$(date +%Y%m%d).json'
      if [[ -f \"\$report_file\" ]]; then
        total=\$(jq -r '.total_cancelled // 0' \"\$report_file\" 2>/dev/null || echo '0')
        if [[ \"\$total\" -gt 10 ]]; then
          echo \"High cancellation rate: \$total cancelled runs in last 7 days\"
          exit 1
        fi
        echo \"Cancellation rate: OK (\$total cancelled runs in last 7 days)\"
      else
        echo 'Cancellation report not found (may need to run separately)'
        exit 0
      fi
    "
  else
    cr_run_check cancellations -- bash -c "echo 'Cancellation report tool or GitHub CLI not available'; exit 0"
  fi
  
  # Check 7: Known Issues
  cr_run_check known_issues -- bash -c "
    found_issues=0
    if [[ -d '$REPO/g/reports' ]]; then
      while IFS= read -r file; do
        if grep -qi 'known issue\|outstanding\|todo\|fixme' \"\$file\" 2>/dev/null; then
          found_issues=\$((found_issues + 1))
        fi
      done < <(find '$REPO/g/reports' -type f -name '*.md' 2>/dev/null | head -20 || true)
    fi
    if [[ \$found_issues -gt 0 ]]; then
      echo \"Known issues documented: \$found_issues file(s)\"
      exit 0
    fi
    echo 'No known issues found in documentation'
  "
  
  # Generate legacy format reports (for backward compatibility)
  log "📄 Generating legacy format reports..."
  generate_legacy_reports
  
  # Print summary
  echo ""
  echo -e "${BLUE}=== Summary ===${NC}"
  echo -e "Passed: ${GREEN}${CR_PASSES}${NC}"
  echo -e "Failed: ${RED}${CR_FAILS}${NC}"
  echo ""
  echo "Reports:"
  echo "  - Check Runner: $CR_OUTDIR/system_checks_*.{md,json}"
  echo "  - Legacy Format: $REPORT_FILE"
  echo ""
  
  # Exit code based on findings
  if [[ $CR_FAILS -gt 0 ]]; then
    echo -e "${YELLOW}⚠️  Some checks failed - review recommended${NC}"
    exit 0  # Don't fail the script, just report
  else
    echo -e "${GREEN}✅ All checks passed - system healthy${NC}"
    exit 0
  fi
}

# Generate legacy format reports (backward compatibility)
generate_legacy_reports() {
  # Convert check_runner results to legacy format
  local overall_status="✅ HEALTHY"
  if [[ $CR_FAILS -gt 0 ]]; then
    overall_status="⚠️  WARNING"
  fi
  
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
    echo "**Status:** $overall_status"
    echo ""
    echo "**Key Findings:**"
    echo "- Passed Checks: $CR_PASSES"
    echo "- Failed Checks: $CR_FAILS"
    echo ""
    echo "---"
    echo ""
    echo "## Check Results"
    echo ""
    echo "| Check | Status |"
    echo "|-------|--------|"
    local k
    for k in "${(@k)CR_STATUS}"; do
      echo "| $k | ${CR_STATUS[$k]} |"
    done
    echo ""
    echo "---"
    echo ""
    echo "## Detailed Results"
    echo ""
    for k in "${(@k)CR_STATUS}"; do
      echo "### $k"
      echo "**Status:** ${CR_STATUS[$k]}"
      if [[ -n "${CR_STDOUT[$k]:-}" ]]; then
        echo ""
        echo "**Output:**"
        echo "\`\`\`"
        echo "${CR_STDOUT[$k]}"
        echo "\`\`\`"
      fi
      if [[ -n "${CR_STDERR[$k]:-}" ]]; then
        echo ""
        echo "**Errors:**"
        echo "\`\`\`"
        echo "${CR_STDERR[$k]}"
        echo "\`\`\`"
      fi
      echo ""
    done
    echo "---"
    echo ""
    echo "**Review Date:** $(date +%Y-%m-%d)"
    echo "**Generated By:** Comprehensive Alert Review Tool (with check_runner)"
    echo "**Status:** $overall_status"
  } > "$REPORT_FILE"
  
  # Generate JSON summary
  jq -n \
    --arg timestamp "$TIMESTAMP" \
    --argjson passes "$CR_PASSES" \
    --argjson fails "$CR_FAILS" \
    --arg overall "$(if [[ $CR_FAILS -gt 0 ]]; then echo "warning"; else echo "healthy"; fi)" \
    '{
      generated_at: $timestamp,
      overall_status: $overall,
      summary: {
        passed: $passes,
        failed: $fails
      }
    }' > "$JSON_FILE" 2>/dev/null || {
    # Fallback JSON
    cat > "$JSON_FILE" <<EOF
{
  "generated_at": "$TIMESTAMP",
  "overall_status": "$(if [[ $CR_FAILS -gt 0 ]]; then echo "warning"; else echo "healthy"; fi)",
  "summary": {
    "passed": $CR_PASSES,
    "failed": $CR_FAILS
  }
}
EOF
  }
  
  log "✅ Legacy format reports generated: $REPORT_FILE, $JSON_FILE"
}

# Run main function
main "$@"
