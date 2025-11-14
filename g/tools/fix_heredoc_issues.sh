#!/usr/bin/env bash
# Heredoc Issue Fixer
# Applies fixes to heredoc quoting issues found by scan_heredoc_issues.sh

set -euo pipefail

REPORT_FILE="${1:-/tmp/heredoc-scan-report.txt}"

if [[ ! -f "${REPORT_FILE}" ]]; then
    echo "❌ Error: Report file not found: ${REPORT_FILE}"
    echo "Run scan_heredoc_issues.sh first to generate a report"
    exit 1
fi

echo "🔧 Heredoc Issue Fixer"
echo "Report: ${REPORT_FILE}"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

FIXES_APPLIED=0

# Parse report file and extract HIGH severity issues
echo "📋 Analyzing report for fixable issues..."

current_file=""
current_line=""
current_desc=""

while IFS= read -r line; do
    if [[ "$line" =~ ^\[HIGH\] ]]; then
        # Extract file and line
        issue=$(echo "$line" | sed 's/\[HIGH\] //')
        current_file=$(echo "$issue" | cut -d':' -f1)
        current_line=$(echo "$issue" | cut -d':' -f2)
    elif [[ "$line" =~ ^[[:space:]]+Single-quoted ]]; then
        current_desc="$line"

        echo -e "${YELLOW}Found HIGH issue:${NC}"
        echo "  File: ${current_file}"
        echo "  Line: ${current_line}"
        echo "  Issue:${current_desc}"
        echo ""

        # Offer to fix
        read -p "Apply fix? (y/n/q): " -n 1 -r
        echo

        if [[ $REPLY =~ ^[Qq]$ ]]; then
            echo "Quitting..."
            break
        elif [[ $REPLY =~ ^[Yy]$ ]]; then
            # Apply fix: Convert <<'EOF' to <<EOF
            # And extract variables before heredoc

            echo "  Applying fix..."

            # Create backup
            cp "${current_file}" "${current_file}.backup"

            # Read the heredoc section
            heredoc_delimiter=$(sed -n "${current_line}p" "${current_file}" | grep -oE "<<[[:space:]]*['\"]([A-Za-z_][A-Za-z0-9_]*)['\"]" | sed "s/.*['\"]//;s/['\"].*//")

            if [[ -n "$heredoc_delimiter" ]]; then
                # Remove quotes from heredoc delimiter
                sed -i.tmp "${current_line}s/<<[[:space:]]*['\"]${heredoc_delimiter}['\"]/<<${heredoc_delimiter}/" "${current_file}"
                rm -f "${current_file}.tmp"

                echo -e "  ${GREEN}✓ Fixed: Removed quotes from heredoc delimiter${NC}"
                ((FIXES_APPLIED++))

                echo "  ⚠️  Manual step required:"
                echo "     Extract GitHub Actions/shell variables before the heredoc"
                echo "     See: ${current_file}:${current_line}"
                echo ""
            else
                echo -e "  ${RED}✗ Could not detect heredoc delimiter${NC}"
            fi
        fi
    fi
done < "${REPORT_FILE}"

echo ""
echo "═══════════════════════════════════════"
echo "🎉 FIXES COMPLETE"
echo "═══════════════════════════════════════"
echo "Fixes applied: ${FIXES_APPLIED}"

if [[ $FIXES_APPLIED -gt 0 ]]; then
    echo ""
    echo "⚠️  Important: Review changes and complete manual steps!"
    echo ""
    echo "For GitHub Actions variables:"
    echo "  1. Extract \${{ ... }} to shell variables before heredoc"
    echo "  2. Use \${VAR_NAME} syntax inside heredoc"
    echo ""
    echo "Example pattern:"
    echo '  VAR_NAME="${{ github.event.foo }}"'
    echo '  cat <<EOF'
    echo '  Value: ${VAR_NAME}'
    echo '  EOF'
    echo ""
    echo "Backup files created with .backup extension"
fi

exit 0
