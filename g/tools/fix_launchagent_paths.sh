#!/usr/bin/env bash
set -euo pipefail

# LaunchAgent Path Audit & Fix Script
# Fixes broken paths in LaunchAgent plists after repo structure changes
# Version: 1.0
# Date: 2025-10-03

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PLIST_DIR="$HOME/Library/LaunchAgents"
LOG_FILE="$HOME/Library/Logs/02luka/fix_launchagent_paths.log"
REPORT_FILE="$ROOT/g/reports/LAUNCHAGENT_PATH_FIX_$(date +%Y%m%d_%H%M%S).md"

DRY_RUN=false
VERBOSE=false
FIX_COUNT=0
ERROR_COUNT=0

# Path mappings for common fixes
declare -A PATH_FIXES=(
    ["/Users/icmini/02luka/"]="/Users/icmini/My Drive (ittipong.c@gmail.com) (1)/02luka/"
    ["/Users/icmini/My Drive (ittipong.c@gmail.com) (1)/02luka/services/"]="\$HOME/dev/02luka-repo/"
    ["/Users/icmini/My Drive (ittipong.c@gmail.com) (1)/02luka/tools/"]="\$HOME/dev/02luka-repo/tools/"
    ["/Users/icmini/My Drive (ittipong.c@gmail.com) (1)/02luka/bin/"]="\$HOME/dev/02luka-repo/bin/"
    ["/Users/icmini/My Drive (ittipong.c@gmail.com) (1)/02luka/launchd/"]="\$HOME/dev/02luka-repo/launchd/"
)

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Audit and fix broken paths in 02luka LaunchAgent plists.

OPTIONS:
    --dry-run       Show what would be fixed without making changes
    --verbose       Show detailed output
    --fix-all       Fix all detected path issues
    --report-only   Generate report without fixing
    --help          Show this help message

EXAMPLES:
    $0 --dry-run                    # Preview changes
    $0 --fix-all                    # Fix all issues
    $0 --report-only --verbose      # Detailed audit report

EOF
    exit 1
}

log() {
    local msg="$1"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $msg" | tee -a "$LOG_FILE"
}

log_verbose() {
    if [[ "$VERBOSE" == true ]]; then
        echo "$1"
    fi
}

check_path_exists() {
    local path="$1"
    # Expand variables like $HOME
    local expanded_path="${path//\$HOME/$HOME}"
    [[ -e "$expanded_path" ]]
}

extract_plist_paths() {
    local plist="$1"
    plutil -extract ProgramArguments json -o - "$plist" 2>/dev/null || echo "[]"
}

check_plist_paths() {
    local plist="$1"
    local label=$(basename "$plist" .plist)
    local has_issues=false
    local missing_paths=()

    # Get all ProgramArguments
    local args=$(extract_plist_paths "$plist")

    # Check each path
    local i=0
    while true; do
        local path=$(echo "$args" | jq -r ".[$i] // empty" 2>/dev/null)
        [[ -z "$path" ]] && break

        # Only check absolute paths
        if [[ "$path" =~ ^/ ]]; then
            if ! check_path_exists "$path"; then
                has_issues=true
                missing_paths+=("$path")
            fi
        fi

        ((i++)) || true
    done

    if [[ "$has_issues" == true ]]; then
        echo "$label|${missing_paths[*]}"
        return 1
    fi

    return 0
}

suggest_path_fix() {
    local old_path="$1"
    local suggested=""

    # Try each path mapping
    for pattern in "${!PATH_FIXES[@]}"; do
        if [[ "$old_path" == "$pattern"* ]]; then
            local replacement="${PATH_FIXES[$pattern]}"
            suggested="${old_path/#$pattern/$replacement}"

            # Check if suggested path exists
            if check_path_exists "$suggested"; then
                echo "$suggested"
                return 0
            fi
        fi
    done

    # Try parent 02luka → 02luka-repo
    if [[ "$old_path" =~ "/02luka/" ]] && [[ ! "$old_path" =~ "/02luka-repo/" ]]; then
        suggested="${old_path/\/02luka\//\/02luka-repo\/}"
        if check_path_exists "$suggested"; then
            echo "$suggested"
            return 0
        fi
    fi

    echo ""
    return 1
}

fix_plist_path() {
    local plist="$1"
    local old_path="$2"
    local new_path="$3"
    local label=$(basename "$plist" .plist)

    if [[ "$DRY_RUN" == true ]]; then
        log "  [DRY-RUN] Would fix: $old_path → $new_path"
        return 0
    fi

    # Backup plist
    local backup="${plist}.backup-$(date +%Y%m%d%H%M%S)"
    cp "$plist" "$backup"

    # Use sed to replace path
    if sed -i '' "s|$old_path|$new_path|g" "$plist" 2>/dev/null; then
        log "  ✅ Fixed: $old_path → $new_path"
        ((FIX_COUNT++))

        # Reload LaunchAgent
        launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
        sleep 1
        launchctl bootstrap "gui/$(id -u)" "$plist" 2>/dev/null || true

        return 0
    else
        log "  ❌ Failed to fix: $plist"
        mv "$backup" "$plist"  # Restore backup
        ((ERROR_COUNT++))
        return 1
    fi
}

generate_report() {
    local failed_agents=("$@")

    cat > "$REPORT_FILE" << EOF
# LaunchAgent Path Audit Report
**Date:** $(date -Iseconds)
**Script:** fix_launchagent_paths.sh v1.0

## Summary

- **Total Plists:** $(find "$PLIST_DIR" -name "com.02luka.*.plist" | wc -l | tr -d ' ')
- **Failed Agents:** ${#failed_agents[@]}
- **Fixes Applied:** $FIX_COUNT
- **Errors:** $ERROR_COUNT
- **Mode:** $([ "$DRY_RUN" == true ] && echo "DRY-RUN" || echo "LIVE")

## Failed Agents

EOF

    if [[ ${#failed_agents[@]} -eq 0 ]]; then
        echo "✅ No path issues found!" >> "$REPORT_FILE"
    else
        for entry in "${failed_agents[@]}"; do
            local label="${entry%%|*}"
            local paths="${entry#*|}"

            echo "### $label" >> "$REPORT_FILE"
            echo "" >> "$REPORT_FILE"
            echo "**Missing paths:**" >> "$REPORT_FILE"
            for path in $paths; do
                echo "- \`$path\`" >> "$REPORT_FILE"

                # Suggest fix
                local suggested=$(suggest_path_fix "$path")
                if [[ -n "$suggested" ]]; then
                    echo "  - **Suggested:** \`$suggested\`" >> "$REPORT_FILE"
                else
                    echo "  - **Status:** No automatic fix available" >> "$REPORT_FILE"
                fi
            done
            echo "" >> "$REPORT_FILE"
        done
    fi

    cat >> "$REPORT_FILE" << EOF

## Path Mappings Used

EOF

    for pattern in "${!PATH_FIXES[@]}"; do
        echo "- \`$pattern\` → \`${PATH_FIXES[$pattern]}\`" >> "$REPORT_FILE"
    done

    cat >> "$REPORT_FILE" << EOF

## Next Steps

EOF

    if [[ "$DRY_RUN" == true ]]; then
        cat >> "$REPORT_FILE" << EOF
**This was a dry-run.** To apply fixes:

\`\`\`bash
$0 --fix-all
\`\`\`
EOF
    else
        cat >> "$REPORT_FILE" << EOF
**Fixes applied:** $FIX_COUNT
**Errors:** $ERROR_COUNT

Review LaunchAgent status:
\`\`\`bash
launchctl list | grep 02luka | grep -v "^\-\s*0"
\`\`\`
EOF
    fi

    log "Report generated: $REPORT_FILE"
}

main() {
    # Parse arguments
    local report_only=false
    local fix_all=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run) DRY_RUN=true ;;
            --verbose) VERBOSE=true ;;
            --fix-all) fix_all=true ;;
            --report-only) report_only=true ;;
            --help) usage ;;
            *) echo "Unknown option: $1"; usage ;;
        esac
        shift
    done

    # Setup
    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$ROOT/g/reports"

    log "Starting LaunchAgent path audit..."
    log "Plist directory: $PLIST_DIR"
    log "Mode: $([ "$DRY_RUN" == true ] && echo "DRY-RUN" || echo "LIVE")"

    # Scan all plists
    local failed_agents=()
    local total=0

    for plist in "$PLIST_DIR"/com.02luka.*.plist; do
        [[ ! -f "$plist" ]] && continue
        ((total++))

        local label=$(basename "$plist" .plist)
        log_verbose "Checking $label..."

        if ! check_plist_paths "$plist"; then
            local result=$(check_plist_paths "$plist" || echo "$?")
            failed_agents+=("$result")

            if [[ "$fix_all" == true ]]; then
                log "Fixing $label..."

                # Extract missing paths
                local missing_paths=(${result#*|})
                for path in ${missing_paths[@]}; do
                    local suggested=$(suggest_path_fix "$path")
                    if [[ -n "$suggested" ]]; then
                        fix_plist_path "$plist" "$path" "$suggested"
                    else
                        log "  ⚠️  No fix available for: $path"
                    fi
                done
            fi
        fi
    done

    log "Scan complete. Total: $total, Failed: ${#failed_agents[@]}"

    # Generate report
    generate_report "${failed_agents[@]}"

    # Summary
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "LaunchAgent Path Audit Complete"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Total plists:    $total"
    echo "Failed agents:   ${#failed_agents[@]}"
    echo "Fixes applied:   $FIX_COUNT"
    echo "Errors:          $ERROR_COUNT"
    echo "Report:          $REPORT_FILE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [[ ${#failed_agents[@]} -gt 0 ]] && [[ "$fix_all" == false ]]; then
        echo ""
        echo "To fix all issues, run:"
        echo "  $0 --fix-all"
    fi
}

main "$@"
