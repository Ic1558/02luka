#!/usr/bin/env bash
set -euo pipefail

# Smart LaunchAgent Path Fixer
# Fixes broken paths intelligently: repairs what can be fixed, unloads what can't
# Version: 1.0

DRY_RUN=false
VERBOSE=false

# SOT paths
SOT_PATH="/Users/icmini/My Drive (ittipong.c@gmail.com) (1)/02luka"
REPO_PATH="/Users/icmini/My Drive (ittipong.c@gmail.com) (1)/02luka-repo"

# Counters
FIXED=0
UNLOADED=0
SKIPPED=0
ERRORS=0

log() {
    echo "[$(date +'%H:%M:%S')] $1"
}

fix_path() {
    local plist="$1"
    local old_path="$2"
    local new_path="$3"
    local label=$(basename "$plist" .plist)

    if [[ "$DRY_RUN" == true ]]; then
        log "  [DRY-RUN] Would fix: $old_path → $new_path"
        return 0
    fi

    # Backup
    cp "$plist" "${plist}.backup-$(date +%Y%m%d%H%M%S)"

    # Fix with sed
    if sed -i '' "s|$old_path|$new_path|g" "$plist" 2>/dev/null; then
        log "  ✅ Fixed path in $label"

        # Reload
        launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
        sleep 0.5
        launchctl bootstrap "gui/$(id -u)" "$plist" 2>/dev/null && log "     Reloaded successfully" || log "     Reload failed"

        ((FIXED++))
        return 0
    else
        log "  ❌ Failed to fix $label"
        ((ERRORS++))
        return 1
    fi
}

unload_agent() {
    local plist="$1"
    local label=$(basename "$plist" .plist)

    if [[ "$DRY_RUN" == true ]]; then
        log "  [DRY-RUN] Would unload: $label"
        return 0
    fi

    launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true

    # Move plist to disabled
    local disabled_dir="$HOME/Library/LaunchAgents/.disabled"
    mkdir -p "$disabled_dir"
    mv "$plist" "$disabled_dir/" 2>/dev/null && log "  🗑️  Unloaded and disabled: $label" && ((UNLOADED++)) || ((ERRORS++))
}

try_fix_old_02luka() {
    local old_path="$1"

    # Try repo path first
    local try_repo="${old_path//\/Users\/icmini\/02luka\//\/Users\/icmini\/My Drive (ittipong.c@gmail.com) (1)\/02luka-repo\/}"
    [[ -e "$try_repo" ]] && echo "$try_repo" && return 0

    # Try SOT path
    local try_sot="${old_path//\/Users\/icmini\/02luka\//$SOT_PATH\/}"
    [[ -e "$try_sot" ]] && echo "$try_sot" && return 0

    return 1
}

try_fix_parent_02luka() {
    local old_path="$1"

    # Change /02luka/ → /02luka-repo/
    local try_repo="${old_path//\/02luka\//\/02luka-repo\/}"
    [[ -e "$try_repo" ]] && echo "$try_repo" && return 0

    return 1
}

try_find_venv() {
    local old_path="$1"

    # Extract agent name from path
    local agent=""
    if [[ "$old_path" =~ agents/([^/]+)/.venv ]]; then
        agent="${BASH_REMATCH[1]}"
    fi

    [[ -z "$agent" ]] && return 1

    # Try common venv locations
    local locations=(
        "$REPO_PATH/agents/$agent/.venv/bin/python"
        "$SOT_PATH/agents/$agent/.venv/bin/python"
        "$REPO_PATH/agents/$agent/venv/bin/python"
        "$SOT_PATH/agents/$agent/venv/bin/python"
    )

    for loc in "${locations[@]}"; do
        [[ -e "$loc" ]] && echo "$loc" && return 0
    done

    return 1
}

process_broken_plist() {
    local plist="$1"
    local old_path="$2"
    local label=$(basename "$plist" .plist)

    log "Processing: $label"
    log "  Broken: $old_path"

    local new_path=""

    # Strategy 1: Old /Users/icmini/02luka/ paths
    if [[ "$old_path" =~ /Users/icmini/02luka/ ]]; then
        new_path=$(try_fix_old_02luka "$old_path" || echo "")

    # Strategy 2: Parent /02luka/ → /02luka-repo/
    elif [[ "$old_path" =~ /02luka/ ]] && [[ ! "$old_path" =~ /02luka-repo/ ]]; then
        new_path=$(try_fix_parent_02luka "$old_path" || echo "")

    # Strategy 3: Missing venv
    elif [[ "$old_path" =~ .venv/bin/python ]]; then
        new_path=$(try_find_venv "$old_path" || echo "")
    fi

    # Apply fix or unload
    if [[ -n "$new_path" ]]; then
        log "  Found: $new_path"
        fix_path "$plist" "$old_path" "$new_path"
    else
        log "  ⚠️  No fix available - will unload"
        unload_agent "$plist"
    fi

    echo ""
}

main() {
    # Parse args
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run) DRY_RUN=true ;;
            --verbose) VERBOSE=true ;;
            *) echo "Unknown: $1"; exit 1 ;;
        esac
        shift
    done

    log "Smart LaunchAgent Path Fixer"
    log "Mode: $([ "$DRY_RUN" == true ] && echo "DRY-RUN" || echo "LIVE")"
    echo ""

    # Get broken agents
    local broken_agents=()

    for plist in ~/Library/LaunchAgents/com.02luka.*.plist; do
        [[ ! -f "$plist" ]] && continue

        local script=$(plutil -extract ProgramArguments.0 raw "$plist" 2>/dev/null || echo "")

        # Only check /Users/ paths
        if [[ "$script" =~ ^/Users/ ]] && [[ ! -e "$script" ]]; then
            broken_agents+=("$plist|$script")
        fi
    done

    log "Found ${#broken_agents[@]} broken agents"
    echo ""

    # Process each
    for entry in "${broken_agents[@]}"; do
        local plist="${entry%%|*}"
        local script="${entry#*|}"
        process_broken_plist "$plist" "$script"
    done

    # Summary
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Smart Fix Complete"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Fixed:    $FIXED"
    echo "Unloaded: $UNLOADED"
    echo "Errors:   $ERRORS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [[ "$DRY_RUN" == true ]]; then
        echo ""
        echo "To apply changes, run without --dry-run"
    fi
}

main "$@"
