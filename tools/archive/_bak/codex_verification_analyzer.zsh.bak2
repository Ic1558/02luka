#!/usr/bin/env zsh
# codex_verification_analyzer.zsh
# Automated Codex change analysis for verification before GitHub sync
# Usage: ./tools/codex_verification_analyzer.zsh [--output-dir DIR]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUTPUT_DIR="${1:-${REPO_ROOT}/g/reports}"
REPORT_FILE="${OUTPUT_DIR}/codex_automated_analysis_20251114.md"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S %z")

cd "${REPO_ROOT}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Initialize report
cat > "${REPORT_FILE}" << EOF
# Codex Automated Analysis Report
**Generated:** ${TIMESTAMP}  
**Script:** \`tools/codex_verification_analyzer.zsh\`  
**Repository:** \`${REPO_ROOT}\`

---

## Analysis Summary

EOF

echo "🔍 Starting Codex verification analysis..."
echo "📁 Report will be saved to: ${REPORT_FILE}"
echo ""

# Track results
SOT_ISSUES=0
SECRET_ISSUES=0
DESTRUCTIVE_ISSUES=0
CONFLICT_ISSUES=0
TOTAL_ISSUES=0

# Function to append to report
append_report() {
    echo "$1" >> "${REPORT_FILE}"
}

# Function to check and report
check_and_report() {
    local check_name="$1"
    local command="$2"
    local description="$3"
    
    echo "  Checking: ${check_name}..."
    
    if eval "${command}" > /tmp/codex_check_${check_name}.txt 2>&1; then
        local result=$(cat /tmp/codex_check_${check_name}.txt)
        if [ -n "${result}" ]; then
            append_report "### ❌ ${check_name}"
            append_report ""
            append_report "**Status:** ISSUES FOUND"
            append_report ""
            append_report "**Description:** ${description}"
            append_report ""
            append_report "\`\`\`"
            append_report "${result}"
            append_report "\`\`\`"
            append_report ""
            return 1
        else
            append_report "### ✅ ${check_name}"
            append_report ""
            append_report "**Status:** PASS"
            append_report ""
            return 0
        fi
    else
        append_report "### ⚠️  ${check_name}"
        append_report ""
        append_report "**Status:** CHECK FAILED (see error below)"
        append_report ""
        append_report "\`\`\`"
        append_report "$(cat /tmp/codex_check_${check_name}.txt)"
        append_report "\`\`\`"
        append_report ""
        return 2
    fi
}

append_report "## Phase 1: SOT Protection"
append_report ""

# Check 1: SOT directory touches
check_and_report \
    "SOT Directory Protection" \
    "git log --oneline --all --grep='codex\\|Codex\\|CODEX' --name-only | grep -E '^core/|^CLC/|^docs/|^02luka\\.md$' | sort | uniq" \
    "Check if Codex commits modified core/, CLC/, docs/, or 02luka.md"

if [ $? -ne 0 ]; then
    SOT_ISSUES=$((SOT_ISSUES + 1))
    TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
fi

# Check 2: Governance files
check_and_report \
    "Governance Files Protection" \
    "git log --oneline --all --grep='codex\\|Codex\\|CODEX' --name-only | grep -E '^\\.cursorrules$|^memory/cls/ALLOWLIST\\.paths$|^\\.claude/context-map\\.json$' | sort | uniq" \
    "Check if Codex commits modified .cursorrules, ALLOWLIST.paths, or context-map.json"

if [ $? -ne 0 ]; then
    SOT_ISSUES=$((SOT_ISSUES + 1))
    TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
fi

append_report "## Phase 2: Safety Checks"
append_report ""

# Check 3: Hardcoded secrets (basic scan)
check_and_report \
    "Secrets Scan (Basic)" \
    "git log --all --grep='codex\\|Codex\\|CODEX' -p | grep -iE 'password\\s*=\\s*[^\\s]|secret\\s*=\\s*[^\\s]|api_key\\s*=\\s*[^\\s]|token\\s*=\\s*[^\\s]' | grep -v '^\\+.*#.*password' | grep -v '^\\+.*#.*secret' | head -20" \
    "Basic scan for hardcoded secrets in Codex commits (excludes comments)"

if [ $? -ne 0 ]; then
    SECRET_ISSUES=$((SECRET_ISSUES + 1))
    TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
fi

# Check 4: Destructive operations
check_and_report \
    "Destructive Operations" \
    "git log --all --grep='codex\\|Codex\\|CODEX' -p | grep -E 'rm[[:space:]]+-rf|git reset --hard|rm -r|unlink' | grep -v '^\\+.*#.*rm' | head -20" \
    "Check for destructive operations in Codex commits (excludes comments)"

if [ $? -ne 0 ]; then
    DESTRUCTIVE_ISSUES=$((DESTRUCTIVE_ISSUES + 1))
    TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
fi

# Check 5: LaunchAgent changes
LAUNCHAGENT_CHANGES=$(git log --oneline --all --grep="codex\|Codex\|CODEX" --name-only | grep -E "\.plist$|LaunchAgent" | sort | uniq | wc -l | tr -d ' ')
if [ "${LAUNCHAGENT_CHANGES}" -gt 0 ]; then
    append_report "### ⚠️  LaunchAgent Changes"
    append_report ""
    append_report "**Status:** ${LAUNCHAGENT_CHANGES} LaunchAgent file(s) modified"
    append_report ""
    append_report "**Files:**"
    git log --oneline --all --grep="codex\|Codex\|CODEX" --name-only | grep -E "\.plist$|LaunchAgent" | sort | uniq | while read -r file; do
        append_report "- \`${file}\`"
    done
    append_report ""
    append_report "**Action Required:** Verify backups exist and changes are safe"
    append_report ""
else
    append_report "### ✅ LaunchAgent Changes"
    append_report ""
    append_report "**Status:** PASS (no LaunchAgent files modified)"
    append_report ""
fi

append_report "## Phase 3: Conflict Detection"
append_report ""

# Check 6: Merge conflicts
if git merge-tree $(git merge-base origin/main HEAD 2>/dev/null || echo "HEAD") origin/main HEAD 2>/dev/null | grep -q "^+<<<<<<<"; then
    append_report "### ❌ Merge Conflicts Detected"
    append_report ""
    append_report "**Status:** CONFLICTS FOUND"
    append_report ""
    append_report "Merge conflicts detected between local and origin/main"
    append_report ""
    CONFLICT_ISSUES=$((CONFLICT_ISSUES + 1))
    TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
else
    append_report "### ✅ Merge Conflicts"
    append_report ""
    append_report "**Status:** PASS (no conflicts detected)"
    append_report ""
fi

# Check 7: Overlapping changes with recent work
RECENT_FILES=$(mktemp)
CODEX_FILES=$(mktemp)
git log --since="7 days ago" --name-only --pretty=format: | sort | uniq > "${RECENT_FILES}" 2>/dev/null || true
git log --all --grep="codex\|Codex\|CODEX" --name-only --pretty=format: | sort | uniq > "${CODEX_FILES}" 2>/dev/null || true

OVERLAPPING=$(comm -12 "${RECENT_FILES}" "${CODEX_FILES}" | wc -l | tr -d ' ')
rm -f "${RECENT_FILES}" "${CODEX_FILES}"

if [ "${OVERLAPPING}" -gt 0 ]; then
    append_report "### ⚠️  Overlapping Changes with Recent Work"
    append_report ""
    append_report "**Status:** ${OVERLAPPING} file(s) modified by both Codex and recent work"
    append_report ""
    append_report "**Action Required:** Review these files for conflicts"
    append_report ""
else
    append_report "### ✅ Overlapping Changes"
    append_report ""
    append_report "**Status:** PASS (no overlapping changes detected)"
    append_report ""
fi

append_report "## Phase 4: Code Quality"
append_report ""

# Check 8: Error handling patterns
ERROR_HANDLING=$(git log --all --grep="codex\|Codex\|CODEX" -p | grep -E "set -e|trap|error|fail" | head -10 | wc -l | tr -d ' ')
if [ "${ERROR_HANDLING}" -gt 0 ]; then
    append_report "### ✅ Error Handling"
    append_report ""
    append_report "**Status:** PASS (error handling patterns found)"
    append_report ""
else
    append_report "### ⚠️  Error Handling"
    append_report ""
    append_report "**Status:** WARNING (limited error handling patterns found)"
    append_report ""
    append_report "**Action Required:** Review scripts for proper error handling"
    append_report ""
fi

# Summary
append_report "---"
append_report ""
append_report "## Summary"
append_report ""
append_report "| Category | Status | Issues Found |"
append_report "|----------|--------|--------------|"
append_report "| SOT Protection | $([ ${SOT_ISSUES} -eq 0 ] && echo '✅ PASS' || echo '❌ FAIL') | ${SOT_ISSUES} |"
append_report "| Safety Checks | $([ ${SECRET_ISSUES} -eq 0 ] && [ ${DESTRUCTIVE_ISSUES} -eq 0 ] && echo '✅ PASS' || echo '⚠️  WARN') | $((SECRET_ISSUES + DESTRUCTIVE_ISSUES)) |"
append_report "| Conflict Detection | $([ ${CONFLICT_ISSUES} -eq 0 ] && echo '✅ PASS' || echo '❌ FAIL') | ${CONFLICT_ISSUES} |"
append_report "| **TOTAL** | **$([ ${TOTAL_ISSUES} -eq 0 ] && echo '✅ PASS' || echo '❌ FAIL')** | **${TOTAL_ISSUES}** |"
append_report ""

if [ ${TOTAL_ISSUES} -eq 0 ]; then
    append_report "### ✅ Overall Status: PASS"
    append_report ""
    append_report "No critical issues found. Codex changes appear safe for review."
    append_report ""
else
    append_report "### ⚠️  Overall Status: ISSUES FOUND"
    append_report ""
    append_report "**${TOTAL_ISSUES} issue(s) found that require review before enabling sync.**"
    append_report ""
    append_report "**Next Steps:**"
    append_report "1. Review all flagged issues above"
    append_report "2. Address critical issues (SOT touches, conflicts)"
    append_report "3. Document resolution for warnings"
    append_report "4. Re-run analysis after fixes"
    append_report ""
fi

append_report "---"
append_report ""
append_report "**Report Generated:** ${TIMESTAMP}"
append_report "**Script Version:** 1.0"
append_report ""

echo ""
if [ ${TOTAL_ISSUES} -eq 0 ]; then
    echo "${GREEN}✅ Analysis complete: PASS${NC}"
else
    echo "${YELLOW}⚠️  Analysis complete: ${TOTAL_ISSUES} issue(s) found${NC}"
fi
echo "📄 Report saved to: ${REPORT_FILE}"
echo ""

exit $([ ${TOTAL_ISSUES} -eq 0 ] && echo 0 || echo 1)
