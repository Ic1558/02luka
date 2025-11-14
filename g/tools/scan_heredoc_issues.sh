#!/usr/bin/env bash
# Heredoc and Path Issue Scanner
# Scans repository for potential heredoc quoting issues

set -uo pipefail

REPO_ROOT="${1:-.}"
REPORT_FILE="${REPORT_FILE:-/tmp/heredoc-scan-report.txt}"

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "🔍 Scanning repository for heredoc and path issues..."
echo "Repository: ${REPO_ROOT}"
echo "Report will be saved to: ${REPORT_FILE}"
echo ""

# Clear previous report
> "${REPORT_FILE}"

ISSUES_FOUND=0

echo "📋 Phase 1: Scanning for single-quoted heredocs with variables..."
echo ""

# Scan workflow files specifically for GitHub Actions variables
if [[ -d "${REPO_ROOT}/.github/workflows" ]]; then
    echo "Checking GitHub Actions workflows..."

    shopt -s nullglob
    for file in "${REPO_ROOT}/.github/workflows"/*.yml "${REPO_ROOT}/.github/workflows"/*.yaml; do
        [[ -f "$file" ]] || continue

        # Look for single-quoted heredocs
        while IFS= read -r heredoc_line; do
            # Found a single-quoted heredoc
            delimiter=$(echo "$heredoc_line" | grep -oE "<<[[:space:]]*['\"]([A-Za-z_][A-Za-z0-9_]*)['\"]" | sed "s/.*['\"]//;s/['\"].*//")

            if [[ -n "$delimiter" ]]; then
                # Check if subsequent lines contain GitHub Actions variables
                context=$(grep -A 20 "<<[[:space:]]*['\"]${delimiter}['\"]" "$file" | grep -E '\$\{\{')

                if [[ -n "$context" ]]; then
                    line_num=$(grep -n "<<[[:space:]]*['\"]${delimiter}['\"]" "$file" | head -1 | cut -d: -f1)

                    echo -e "${RED}⚠ HIGH${NC}: ${file}:${line_num}"
                    echo "  Single-quoted heredoc '${delimiter}' contains GitHub Actions variables"
                    echo "  Variables like \${{ ... }} will NOT expand"
                    echo ""

                    echo "[HIGH] ${file}:${line_num}" >> "${REPORT_FILE}"
                    echo "  Single-quoted heredoc '${delimiter}' prevents GitHub Actions variable expansion" >> "${REPORT_FILE}"
                    echo "" >> "${REPORT_FILE}"

                    ((ISSUES_FOUND++)) || true
                fi
            fi
        done < <(grep -n "<<[[:space:]]*['\"]" "$file" 2>/dev/null || true)
    done
fi

# Scan shell scripts for variable expansion issues
echo "Checking shell scripts..."

for ext in sh bash zsh; do
    while IFS= read -r file; do
        [[ -f "$file" ]] || continue

        # Look for single-quoted heredocs
        while IFS=: read -r line_num line_content; do
            # Found a single-quoted heredoc
            delimiter=$(echo "$line_content" | grep -oE "<<[[:space:]]*['\"]([A-Za-z_][A-Za-z0-9_]*)['\"]" | sed "s/.*['\"]//;s/['\"].*//")

            if [[ -n "$delimiter" ]]; then
                # Check if subsequent lines contain shell variables
                context=$(grep -A 20 "<<[[:space:]]*['\"]${delimiter}['\"]" "$file" | grep -E '\$[{(]')

                if [[ -n "$context" ]]; then
                    echo -e "${YELLOW}⚠ MEDIUM${NC}: ${file}:${line_num}"
                    echo "  Single-quoted heredoc '${delimiter}' contains shell variables"
                    echo "  Variables like \$VAR or \$(cmd) will NOT expand"
                    echo ""

                    echo "[MEDIUM] ${file}:${line_num}" >> "${REPORT_FILE}"
                    echo "  Single-quoted heredoc '${delimiter}' prevents shell variable expansion" >> "${REPORT_FILE}"
                    echo "" >> "${REPORT_FILE}"

                    ((ISSUES_FOUND++)) || true
                fi
            fi
        done < <(grep -n "<<[[:space:]]*['\"]" "$file" 2>/dev/null || true)

    done < <(find "${REPO_ROOT}" -type f -name "*.${ext}" ! -path "*/.git/*" ! -path "*/node_modules/*" 2>/dev/null || true)
done

echo ""
echo "📋 Phase 2: Scanning for hardcoded paths..."
echo ""

# Check for hardcoded home paths
for ext in sh bash zsh yml yaml; do
    while IFS= read -r file; do
        [[ -f "$file" ]] || continue

        while IFS=: read -r line_num line_content; do
            # Skip comments
            if echo "$line_content" | grep -qE '^[[:space:]]*(#|//)'; then
                continue
            fi

            path=$(echo "$line_content" | grep -oE '(/home/[^/]+|/Users/[^/]+)' | head -1)

            if [[ -n "$path" ]]; then
                echo -e "${BLUE}ℹ INFO${NC}: ${file}:${line_num}"
                echo "  Hardcoded path detected: ${path}"
                echo "  Consider using \${HOME} or environment variables"
                echo ""

                echo "[INFO] ${file}:${line_num}" >> "${REPORT_FILE}"
                echo "  Hardcoded path detected: ${path}" >> "${REPORT_FILE}"
                echo "" >> "${REPORT_FILE}"

                ((ISSUES_FOUND++)) || true
            fi
        done < <(grep -nE '(/home/[^/]+|/Users/[^/]+)' "$file" 2>/dev/null | head -10 || true)

    done < <(find "${REPO_ROOT}" -type f -name "*.${ext}" ! -path "*/.git/*" ! -path "*/node_modules/*" 2>/dev/null || true)
done

echo ""
echo "═══════════════════════════════════════"
echo "📊 SCAN COMPLETE"
echo "═══════════════════════════════════════"

if [[ $ISSUES_FOUND -eq 0 ]]; then
    echo -e "${GREEN}✓ No issues found!${NC}"
    echo "Repository follows heredoc best practices."
else
    echo -e "${YELLOW}Found ${ISSUES_FOUND} potential issue(s)${NC}"
    echo ""
    echo "Detailed report saved to: ${REPORT_FILE}"
    echo ""
    echo "Review the report with:"
    echo "  cat ${REPORT_FILE}"
    echo ""
    echo "Apply fixes interactively:"
    echo "  ./tools/fix_heredoc_issues.sh ${REPORT_FILE}"
fi

echo ""
exit 0
