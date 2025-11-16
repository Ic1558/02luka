#!/usr/bin/env zsh
# workerctl - Local Worker Verification CLI
# Manages WORKER_REGISTRY.yaml and verifies worker health

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REGISTRY_FILE="$REPO_ROOT/g/docs/WORKER_REGISTRY.yaml"
LAUNCHAGENTS_DIR="$HOME/Library/LaunchAgents"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper: Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Helper: Parse YAML (simple extraction, requires Python or yq)
parse_yaml() {
    local key="$1"
    if command_exists yq; then
        yq eval "$key" "$REGISTRY_FILE" 2>/dev/null
    elif command_exists python3; then
        python3 <<PYEOF
import yaml
import sys
try:
    with open("$REGISTRY_FILE", 'r') as f:
        data = yaml.safe_load(f)
    workers = data.get('workers', [])
    for w in workers:
        if w.get('id') == "$key":
            print(yaml.dump(w, default_flow_style=False))
            sys.exit(0)
    sys.exit(1)
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)
PYEOF
    else
        echo "Error: Need 'yq' or 'python3' with PyYAML to parse YAML" >&2
        exit 1
    fi
}

# Get all worker IDs from registry
get_worker_ids() {
    if command_exists yq; then
        yq eval '.workers[].id' "$REGISTRY_FILE" 2>/dev/null
    elif command_exists python3; then
        python3 <<PYEOF
import yaml
try:
    with open("$REGISTRY_FILE", 'r') as f:
        data = yaml.safe_load(f)
    for w in data.get('workers', []):
        print(w.get('id', ''))
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
PYEOF
    fi
}

# Get worker entrypoint
get_worker_entrypoint() {
    local worker_id="$1"
    if command_exists yq; then
        yq eval ".workers[] | select(.id == \"$worker_id\") | .entrypoint" "$REGISTRY_FILE" 2>/dev/null
    elif command_exists python3; then
        python3 <<PYEOF
import yaml
import sys
try:
    with open("$REGISTRY_FILE", 'r') as f:
        data = yaml.safe_load(f)
    for w in data.get('workers', []):
        if w.get('id') == "$worker_id":
            print(w.get('entrypoint', ''))
            sys.exit(0)
    sys.exit(1)
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)
PYEOF
    fi
}

# Get worker health check command
get_worker_health_check() {
    local worker_id="$1"
    if command_exists yq; then
        yq eval ".workers[] | select(.id == \"$worker_id\") | .health_check.command" "$REGISTRY_FILE" 2>/dev/null
    elif command_exists python3; then
        python3 <<PYEOF
import yaml
import sys
try:
    with open("$REGISTRY_FILE", 'r') as f:
        data = yaml.safe_load(f)
    for w in data.get('workers', []):
        if w.get('id') == "$worker_id":
            hc = w.get('health_check', {})
            print(hc.get('command', ''))
            sys.exit(0)
    sys.exit(1)
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)
PYEOF
    fi
}

# Get worker timeout
get_worker_timeout() {
    local worker_id="$1"
    if command_exists yq; then
        yq eval ".workers[] | select(.id == \"$worker_id\") | .health_check.timeout_sec // 10" "$REGISTRY_FILE" 2>/dev/null
    elif command_exists python3; then
        python3 <<PYEOF
import yaml
import sys
try:
    with open("$REGISTRY_FILE", 'r') as f:
        data = yaml.safe_load(f)
    for w in data.get('workers', []):
        if w.get('id') == "$worker_id":
            hc = w.get('health_check', {})
            print(hc.get('timeout_sec', 10))
            sys.exit(0)
    print(10)
    sys.exit(0)
except Exception as e:
    print(10)
    sys.exit(0)
PYEOF
    fi
}

# Verify worker (L0-L3 levels)
verify_worker() {
    local worker_id="$1"
    local entrypoint=$(get_worker_entrypoint "$worker_id")
    local health_cmd=$(get_worker_health_check "$worker_id")
    local timeout=$(get_worker_timeout "$worker_id")
    
    if [ -z "$entrypoint" ]; then
        echo "L0"  # Declared only
        return
    fi
    
    # L1: Entrypoint exists
    if [ ! -f "$entrypoint" ]; then
        echo "L0"
        return
    fi
    
    if [ ! -x "$entrypoint" ]; then
        echo "L1"  # Exists but not executable
        return
    fi
    
    # L2: Health check passes
    if [ -n "$health_cmd" ]; then
        if timeout "${timeout}s" zsh -c "$health_cmd" >/dev/null 2>&1; then
            # L3: Check for evidence of work (simplified - check logs)
            local log_evidence=$(find "$REPO_ROOT/logs" -name "*.log" -type f -mtime -1 2>/dev/null | xargs grep -l "$worker_id" 2>/dev/null | head -1)
            if [ -n "$log_evidence" ]; then
                echo "L3"
            else
                echo "L2"
            fi
        else
            echo "L1"  # Exists but health check fails
        fi
    else
        echo "L1"  # Exists but no health check defined
    fi
}

# List all workers
cmd_list() {
    printf "%-20s %-10s %-6s %-20s %-40s %s\n" "ID" "STATUS" "LEVEL" "LAST_SUCCESS" "LAUNCHAGENT" "STATUS"
    printf "%-20s %-10s %-6s %-20s %-40s %s\n" "$(printf '%.0s-' {1..20})" "$(printf '%.0s-' {1..10})" "$(printf '%.0s-' {1..6})" "$(printf '%.0s-' {1..20})" "$(printf '%.0s-' {1..40})" "$(printf '%.0s-' {1..10})"
    
    for worker_id in $(get_worker_ids); do
        local level=$(verify_worker "$worker_id")
        local entrypoint=$(get_worker_entrypoint "$worker_id")
        local worker_status="OK"
        local icon="✅"
        
        if [ "$level" = "L0" ]; then
            worker_status="BROKEN"
            icon="❌"
        elif [ "$level" = "L1" ]; then
            worker_status="BROKEN"
            icon="⚠️"
        fi
        
        # Find LaunchAgent label
        local launchagent_label=""
        if command_exists python3; then
            launchagent_label=$(python3 <<PYEOF
import yaml
try:
    with open("$REGISTRY_FILE", 'r') as f:
        data = yaml.safe_load(f)
    for w in data.get('workers', []):
        if w.get('id') == "$worker_id":
            labels = w.get('launchagent_labels', [])
            if labels:
                print(labels[0])
            break
except:
    pass
PYEOF
)
        fi
        
        # Check if LaunchAgent exists and is active
        local la_status=""
        if [ -n "$launchagent_label" ]; then
            if [ -f "$LAUNCHAGENTS_DIR/$launchagent_label.plist" ]; then
                la_status="✅"
            elif [ -f "$LAUNCHAGENTS_DIR/.disabled/$launchagent_label.plist" ]; then
                la_status="❌"
            else
                la_status="⚠️"
            fi
        fi
        
        printf "%-20s %-10s %-6s %-20s %-40s %s\n" \
            "$worker_id" \
            "$worker_status" \
            "$level" \
            "-" \
            "${launchagent_label:-none}" \
            "$la_status"
    done
}

# Verify single worker
cmd_verify() {
    local worker_id="$1"
    
    if [ -z "$worker_id" ] || [ "$worker_id" = "--all" ]; then
        echo "Usage: workerctl verify <worker-id>" >&2
        exit 1
    fi
    
    echo "Verifying worker: $worker_id"
    local level=$(verify_worker "$worker_id")
    local entrypoint=$(get_worker_entrypoint "$worker_id")
    
    echo "  Entrypoint: ${entrypoint:-NOT FOUND}"
    echo "  Verification Level: $level"
    
    case "$level" in
        L0) echo "  Status: ${RED}BROKEN${NC} - Declared only, entrypoint missing" ;;
        L1) echo "  Status: ${YELLOW}EXISTS${NC} - Entrypoint exists but health check fails" ;;
        L2) echo "  Status: ${GREEN}LAUNCHABLE${NC} - Health check passes" ;;
        L3) echo "  Status: ${GREEN}PRODUCING VALUE${NC} - Verified and producing work" ;;
    esac
}

# Verify all workers
cmd_verify_all() {
    echo "Verifying all workers..."
    echo ""
    
    for worker_id in $(get_worker_ids); do
        cmd_verify "$worker_id"
        echo ""
    done
    
    echo "Verification complete. Run 'workerctl list' for summary."
}

# Scan LaunchAgents and match against registry
cmd_scan_launchagents() {
    echo "Scanning LaunchAgents and matching against registry..."
    echo ""
    
    local orphans=0
    local matched=0
    local invalid=0
    
    for plist in "$LAUNCHAGENTS_DIR"/com.02luka.*.plist "$LAUNCHAGENTS_DIR"/.disabled/com.02luka.*.plist; do
        [ -f "$plist" ] || continue
        
        local label=$(basename "$plist" .plist)
        local disabled=""
        if [[ "$plist" == *"/.disabled/"* ]]; then
            disabled=" (DISABLED)"
        fi
        
        # Extract entrypoint
        local entrypoint=""
        if command_exists python3; then
            entrypoint=$(python3 <<PYEOF
import plistlib
try:
    with open("$plist", 'rb') as f:
        plist = plistlib.load(f)
    args = plist.get('ProgramArguments', [])
    if args:
        print(args[0])
except:
    pass
PYEOF
)
        fi
        
        # Check if entrypoint matches registry
        local found=false
        for worker_id in $(get_worker_ids); do
            local reg_entrypoint=$(get_worker_entrypoint "$worker_id")
            if [ "$entrypoint" = "$reg_entrypoint" ]; then
                local level=$(verify_worker "$worker_id")
                echo "✅ MATCHED: $label → $worker_id (Level: $level)$disabled"
                matched=$((matched + 1))
                found=true
                
                if [ "$level" = "L0" ] || [ "$level" = "L1" ]; then
                    echo "   ⚠️  INVALID: Worker is L0/L1, LaunchAgent should be disabled"
                    invalid=$((invalid + 1))
                fi
                break
            fi
        done
        
        if [ "$found" = false ]; then
            echo "⚠️  ORPHAN: $label → entrypoint: ${entrypoint:-NOT FOUND}$disabled"
            orphans=$((orphans + 1))
        fi
    done
    
    echo ""
    echo "Summary:"
    echo "  Matched: $matched"
    echo "  Orphans: $orphans"
    echo "  Invalid (L0/L1): $invalid"
}

# Prune invalid LaunchAgents
cmd_prune() {
    local dry_run=true
    if [ "${1:-}" = "--force" ]; then
        dry_run=false
    fi
    
    if [ "$dry_run" = true ]; then
        echo "DRY RUN: Would disable the following LaunchAgents:"
        echo ""
    else
        echo "DISABLING invalid LaunchAgents..."
        echo ""
    fi
    
    local disabled_count=0
    
    for worker_id in $(get_worker_ids); do
        local level=$(verify_worker "$worker_id")
        
        if [ "$level" = "L0" ] || [ "$level" = "L1" ]; then
            # Get LaunchAgent label
            local launchagent_label=""
            if command_exists python3; then
                launchagent_label=$(python3 <<PYEOF
import yaml
try:
    with open("$REGISTRY_FILE", 'r') as f:
        data = yaml.safe_load(f)
    for w in data.get('workers', []):
        if w.get('id') == "$worker_id":
            labels = w.get('launchagent_labels', [])
            if labels:
                print(labels[0])
            break
except:
    pass
PYEOF
)
            fi
            
            if [ -n "$launchagent_label" ] && [ -f "$LAUNCHAGENTS_DIR/$launchagent_label.plist" ]; then
                if [ "$dry_run" = true ]; then
                    echo "  Would disable: $launchagent_label (worker: $worker_id, level: $level)"
                else
                    echo "  Disabling: $launchagent_label (worker: $worker_id, level: $level)"
                    mkdir -p "$LAUNCHAGENTS_DIR/.disabled"
                    mv "$LAUNCHAGENTS_DIR/$launchagent_label.plist" "$LAUNCHAGENTS_DIR/.disabled/$launchagent_label.plist"
                    launchctl unload "$LAUNCHAGENTS_DIR/.disabled/$launchagent_label.plist" 2>/dev/null || true
                    disabled_count=$((disabled_count + 1))
                fi
            fi
        fi
    done
    
    if [ "$dry_run" = true ]; then
        echo ""
        echo "Run 'workerctl prune --force' to actually disable these LaunchAgents."
    else
        echo ""
        echo "Disabled $disabled_count LaunchAgent(s)."
    fi
}

# Main command dispatcher
main() {
    if [ ! -f "$REGISTRY_FILE" ]; then
        echo "Error: Registry file not found: $REGISTRY_FILE" >&2
        exit 1
    fi
    
    case "${1:-}" in
        list)
            cmd_list
            ;;
        verify)
            if [ "${2:-}" = "--all" ]; then
                cmd_verify_all
            else
                cmd_verify "${2:-}"
            fi
            ;;
        scan-launchagents)
            cmd_scan_launchagents
            ;;
        prune)
            cmd_prune "${2:-}"
            ;;
        --version)
            echo "workerctl v1.0.0"
            ;;
        *)
            echo "Usage: workerctl {list|verify|scan-launchagents|prune}" >&2
            echo "" >&2
            echo "Commands:" >&2
            echo "  list                 List all workers with status" >&2
            echo "  verify <id>          Verify single worker" >&2
            echo "  verify --all          Verify all workers" >&2
            echo "  scan-launchagents     Scan LaunchAgents and match against registry" >&2
            echo "  prune --dry-run      Show what would be disabled" >&2
            echo "  prune --force         Actually disable invalid LaunchAgents" >&2
            exit 1
            ;;
    esac
}

main "$@"

