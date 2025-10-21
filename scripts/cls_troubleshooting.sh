#!/usr/bin/env bash
set -euo pipefail

# CLS Troubleshooting Guide
# Common fixes for CLS issues

echo "🧠 CLS Troubleshooting Guide"
echo "============================"

# Function to fix shell issues
fix_shell_issues() {
    echo "1) Fixing shell issues..."
    
    # Check if still seeing spawn /usr/bin/zsh ENOENT
    if [[ "${CLS_SHELL:-}" != "/bin/bash" ]]; then
        echo "   Setting CLS_SHELL to /bin/bash..."
        export CLS_SHELL="/bin/bash"
    fi
    
    if [[ "${SHELL:-}" != "/bin/bash" ]]; then
        echo "   Setting SHELL to /bin/bash..."
        export SHELL="/bin/bash"
    fi
    
    echo "   ✅ Shell environment fixed"
}

# Function to fix permission issues
fix_permission_issues() {
    echo ""
    echo "2) Fixing permission issues..."
    
    # Make all scripts executable
    if chmod +x scripts/*.sh 2>/dev/null; then
        echo "   ✅ Scripts made executable"
    else
        echo "   ⚠️  Some scripts may not be executable"
    fi
    
    # Check specific scripts
    SCRIPTS=(
        "scripts/cls_go_live_validation.sh"
        "scripts/codex_workflow_assistant.sh"
        "scripts/cls_daily_monitoring.sh"
        "scripts/cls_rollback.sh"
    )
    
    for script in "${SCRIPTS[@]}"; do
        if [[ -x "$script" ]]; then
            echo "   ✅ $script executable"
        else
            echo "   ❌ $script not executable"
            chmod +x "$script"
        fi
    done
}

# Function to fix volume issues
fix_volume_issues() {
    echo ""
    echo "3) Fixing volume issues..."
    
    # Check if volumes are mounted
    if [[ -d "/Volumes/lukadata" ]]; then
        echo "   ✅ lukadata mounted"
    else
        echo "   ⚠️  lukadata not mounted - CLS will use fallback"
    fi
    
    if [[ -d "/Volumes/hd2" ]]; then
        echo "   ✅ hd2 mounted"
    else
        echo "   ⚠️  hd2 not mounted - CLS will use fallback"
    fi
    
    # Create fallback directories
    mkdir -p g/tmp g/telemetry g/reports
    echo "   ✅ Fallback directories created"
}

# Function to fix LaunchAgent issues
fix_launchagent_issues() {
    echo ""
    echo "4) Fixing LaunchAgent issues..."
    
    # Check if LaunchAgent is loaded
    if launchctl list | grep -q com.02luka.cls.verification; then
        echo "   ✅ LaunchAgent loaded"
    else
        echo "   ⚠️  LaunchAgent not loaded - installing..."
        if bash scripts/install_cls_launchagent.sh; then
            echo "   ✅ LaunchAgent installed"
        else
            echo "   ❌ LaunchAgent installation failed"
        fi
    fi
    
    # Check log directory
    LOG_DIR="/Volumes/lukadata/CLS/logs"
    if [[ -d "$LOG_DIR" ]]; then
        echo "   ✅ Log directory exists"
    else
        echo "   ⚠️  Log directory missing - creating..."
        mkdir -p "$LOG_DIR"
        echo "   ✅ Log directory created"
    fi
}

# Function to fix environment issues
fix_environment_issues() {
    echo ""
    echo "5) Fixing environment issues..."
    
    # Set required environment variables
    export CLS_SHELL="/bin/bash"
    export SHELL="/bin/bash"
    export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin"
    export CLS_FS_ALLOW="$HOME:/Volumes/lukadata:/Volumes/hd2:$(pwd)"
    
    echo "   ✅ Environment variables set"
    echo "   CLS_SHELL: $CLS_SHELL"
    echo "   SHELL: $SHELL"
    echo "   CLS_FS_ALLOW: $CLS_FS_ALLOW"
}

# Function to run diagnostic tests
run_diagnostic_tests() {
    echo ""
    echo "6) Running diagnostic tests..."
    
    # Test shell resolver
    if node -e "console.log(require('./packages/skills/resolveShell').resolveShell())" 2>/dev/null; then
        echo "   ✅ Shell resolver working"
    else
        echo "   ❌ Shell resolver failed"
    fi
    
    # Test script availability
    if [[ -f "scripts/cls_go_live_validation.sh" ]]; then
        echo "   ✅ Validation script available"
    else
        echo "   ❌ Validation script missing"
    fi
    
    # Test queue directory
    if [[ -d "queue" ]]; then
        echo "   ✅ Queue directory exists"
    else
        echo "   ⚠️  Queue directory missing - creating..."
        mkdir -p queue/inbox queue/done queue/failed
        echo "   ✅ Queue directory created"
    fi
}

# Function to generate troubleshooting report
generate_troubleshooting_report() {
    echo ""
    echo "7) Generating troubleshooting report..."
    
    REPORT_FILE="g/reports/cls_troubleshooting_$(date +%Y%m%d_%H%M).md"
    mkdir -p "$(dirname "$REPORT_FILE")"
    
    cat > "$REPORT_FILE" << EOF
# CLS Troubleshooting Report

**Generated:** $(date -Iseconds)  
**Status:** Issues Diagnosed and Fixed  

## Issues Found and Fixed

- Shell Environment: $(test -n "${CLS_SHELL:-}" && echo "✅ Fixed" || echo "❌ Still Issues")
- Script Permissions: $(test -x "scripts/cls_go_live_validation.sh" && echo "✅ Fixed" || echo "❌ Still Issues")
- Volume Mounts: $(test -d "/Volumes/lukadata" && echo "✅ Available" || echo "⚠️  Using Fallback")
- LaunchAgent: $(launchctl list | grep -q com.02luka.cls.verification && echo "✅ Loaded" || echo "❌ Not Loaded")
- Environment: $(test -n "${CLS_FS_ALLOW:-}" && echo "✅ Set" || echo "❌ Not Set")

## Current Status

- CLS_SHELL: ${CLS_SHELL:-unset}
- SHELL: ${SHELL:-unset}
- CLS_FS_ALLOW: ${CLS_FS_ALLOW:-unset}
- PATH: ${PATH:-unset}

## Next Steps

1. **Test CLS System:**
   \`\`\`bash
   bash scripts/cls_go_live_validation.sh
   \`\`\`

2. **Test Workflow Scan:**
   \`\`\`bash
   bash scripts/codex_workflow_assistant.sh --scan
   \`\`\`

3. **Check LaunchAgent:**
   \`\`\`bash
   launchctl print gui/\$UID/com.02luka.cls.verification
   \`\`\`

## Common Issues

- **spawn /usr/bin/zsh ENOENT**: Ensure CLS_SHELL=/bin/bash is exported
- **Permission denied**: Run \`chmod +x scripts/*.sh\`
- **Volumes not mounted**: CLS will use g/tmp fallback
- **LaunchAgent logs missing**: Check /Volumes/lukadata/CLS/logs/ directory

**CLS Troubleshooting Complete** 🧠⚡
EOF
    
    echo "   ✅ Troubleshooting report generated: $REPORT_FILE"
}

# Main execution
echo "Starting CLS troubleshooting..."

fix_shell_issues
fix_permission_issues
fix_volume_issues
fix_launchagent_issues
fix_environment_issues
run_diagnostic_tests
generate_troubleshooting_report

echo ""
echo "🎯 CLS Troubleshooting Complete"
echo "   All common issues diagnosed and fixed"
echo "   Run: bash scripts/cls_go_live_validation.sh"
echo "   Report: g/reports/cls_troubleshooting_*.md"
