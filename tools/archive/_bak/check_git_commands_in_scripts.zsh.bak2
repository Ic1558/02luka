#!/usr/bin/env zsh
# ═══════════════════════════════════════════════════════════════════════
# Check Git Commands in Scripts
# ═══════════════════════════════════════════════════════════════════════
# Lint script to find git commands that may cause ambiguous argument errors
# ═══════════════════════════════════════════════════════════════════════

set -euo pipefail

ROOT="${LUKA_SOT:-${HOME}/02luka}"
SCRIPT_DIR="${ROOT}/tools"

# Patterns that indicate problematic git commands
PROBLEMATIC_PATTERNS=(
    'git diff.*\$.*\$'           # git diff $VAR$FILE (concatenation)
    'git log.*\$.*\$'            # git log $VAR$FILE (concatenation)
    'git checkout.*\$.*\$'       # git checkout $VAR$FILE (concatenation)
)

check_file() {
    local file="$1"
    local issues=0

    echo "Checking: $file"

    for pattern in "${PROBLEMATIC_PATTERNS[@]}"; do
        if grep -qE "$pattern" "$file" 2>/dev/null; then
            echo "  ⚠️  Found problematic pattern: $pattern"
            grep -nE "$pattern" "$file" | head -3 | sed 's/^/    /'
            issues=$((issues + 1))
        fi
    done

    # Heuristic: git diff/log/checkout with two variable-looking args and no --
    if grep -qE 'git (diff|log|checkout) [^"\n]*\$[^"\n]* [^"\n]*\$' "$file" 2>/dev/null && ! grep -qE 'git (diff|log|checkout).*--' "$file" 2>/dev/null; then
        echo "  ⚠️  Found git command that may need -- separator"
        grep -nE 'git (diff|log|checkout) [^"\n]*\$[^"\n]* [^"\n]*\$' "$file" | head -3 | sed 's/^/    /'
        issues=$((issues + 1))
    fi

    if [[ $issues -eq 0 ]]; then
        echo "  ✅ No issues found"
    fi

    return $issues
}

main() {
    local total_issues=0
    local files_checked=0

    echo "🔍 Checking Git Commands in Scripts"
    echo "===================================="
    echo ""

    for file in "$SCRIPT_DIR"/*.zsh "$SCRIPT_DIR"/*.sh; do
        if [[ -f "$file" ]] && [[ -r "$file" ]]; then
            files_checked=$((files_checked + 1))
            check_file "$file"
            rc=$?
            if [[ $rc -gt 0 ]]; then
                total_issues=$((total_issues + rc))
            fi
            echo ""
        fi
    done

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Files checked: $files_checked"
    echo "Total issues: $total_issues"
    echo ""

    if [[ $total_issues -eq 0 ]]; then
        echo "✅ All git commands are safe"
        return 0
    else
        echo "⚠️  Found $total_issues issue(s) - review needed"
        return 1
    fi
}

main "$@"
