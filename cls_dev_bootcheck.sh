#!/usr/bin/env bash
set -euo pipefail

# CLS Dev Bootcheck
# Runs at shell startup to assert CLS environment is ready

echo "🧠 CLS Dev Bootcheck"
echo "==================="

# Function to check shell environment
check_shell_environment() {
    echo "1) Checking shell environment..."
    
    # Check CLS_SHELL
    if [[ -n "${CLS_SHELL:-}" ]]; then
        echo "   ✅ CLS_SHELL: $CLS_SHELL"
    else
        echo "   ⚠️  CLS_SHELL not set - setting to /bin/bash"
        export CLS_SHELL="/bin/bash"
    fi
    
    # Check SHELL
    if [[ -n "${SHELL:-}" ]]; then
        echo "   ✅ SHELL: $SHELL"
    else
        echo "   ⚠️  SHELL not set - setting to /bin/bash"
        export SHELL="/bin/bash"
    fi
    
    # Check PATH
    if [[ "$PATH" == *"/usr/local/bin"* ]] && [[ "$PATH" == *"/usr/bin"* ]]; then
        echo "   ✅ PATH configured"
    else
        echo "   ⚠️  PATH incomplete - setting full path"
        export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin"
    fi
}

# Function to check filesystem allowlist
check_filesystem_allowlist() {
    echo ""
    echo "2) Checking filesystem allowlist..."
    
    if [[ -n "${CLS_FS_ALLOW:-}" ]]; then
        echo "   ✅ CLS_FS_ALLOW: $CLS_FS_ALLOW"
    else
        echo "   ⚠️  CLS_FS_ALLOW not set - setting default"
        export CLS_FS_ALLOW="$HOME:/Volumes/lukadata:/Volumes/hd2:$(pwd)"
    fi
}

# Function to test shell resolver
test_shell_resolver() {
    echo ""
    echo "3) Testing shell resolver..."
    
    if [[ -f "packages/skills/resolveShell.js" ]]; then
        RESOLVED=$(node -e "console.log(require('./packages/skills/resolveShell').resolveShell())" 2>/dev/null || echo "unknown")
        echo "   Resolved shell: $RESOLVED"
        
        if [[ "$RESOLVED" == "/bin/bash" ]] || [[ "$RESOLVED" == "/usr/bin/bash" ]]; then
            echo "   ✅ Shell resolver working correctly"
        else
            echo "   ❌ Shell resolver returned unexpected value"
            return 1
        fi
    else
        echo "   ❌ Shell resolver not found"
        return 1
    fi
}

# Function to check core scripts
check_core_scripts() {
    echo ""
    echo "4) Checking core scripts..."
    
    SCRIPTS=(
        "scripts/cls_go_live_validation.sh"
        "scripts/codex_workflow_assistant.sh"
        "scripts/cls_daily_monitoring.sh"
        "scripts/cls_rollback.sh"
    )
    
    for script in "${SCRIPTS[@]}"; do
        if [[ -f "$script" ]]; then
            echo "   ✅ $script"
        else
            echo "   ❌ $script"
            return 1
        fi
    done
}

# Function to check directories
check_directories() {
    echo ""
    echo "5) Checking directories..."
    
    # Create necessary directories
    mkdir -p g/telemetry g/reports g/tmp
    echo "   ✅ Core directories ready"
    
    # Check volume mounts (optional)
    if [[ -d "/Volumes/lukadata" ]]; then
        echo "   ✅ lukadata mounted"
    else
        echo "   ⚠️  lukadata not mounted - will use fallback"
    fi
    
    if [[ -d "/Volumes/hd2" ]]; then
        echo "   ✅ hd2 mounted"
    else
        echo "   ⚠️  hd2 not mounted - will use fallback"
    fi
}

# Function to generate environment summary
generate_summary() {
    echo ""
    echo "6) Environment summary..."
    
    echo "   CLS_SHELL: ${CLS_SHELL:-unset}"
    echo "   SHELL: ${SHELL:-unset}"
    echo "   CLS_FS_ALLOW: ${CLS_FS_ALLOW:-unset}"
    echo "   PATH: ${PATH:-unset}"
    
    # Test if we can run a simple CLS command
    if [[ -f "scripts/cls_go_live_validation.sh" ]]; then
        echo "   ✅ CLS validation script available"
    else
        echo "   ❌ CLS validation script missing"
    fi
}

# Main execution
echo "Starting CLS dev bootcheck..."

check_shell_environment
check_filesystem_allowlist
test_shell_resolver
check_core_scripts
check_directories
generate_summary

echo ""
echo "🎯 CLS Dev Bootcheck Complete"
echo "   Environment is ready for CLS execution"
echo "   Run: bash scripts/cls_go_live_validation.sh"
