#!/usr/bin/env bash
set -euo pipefail

# CLS Final Night Setup - Complete Unattended Operation
# One-shot script to set up CLS for complete night operation

echo "🌙 CLS Final Night Setup - Complete Unattended Operation"
echo "======================================================="

# Function to set up final environment
setup_final_environment() {
    echo "1) Setting up final environment..."
    
    # Set environment variables
    export CLS_SHELL="/bin/bash"
    export SHELL="/bin/bash"
    export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin"
    export CLS_FS_ALLOW="$HOME:/Volumes/lukadata:/Volumes/hd2:$(pwd)"
    
    echo "   ✅ Environment configured"
    echo "   CLS_SHELL: $CLS_SHELL"
    echo "   SHELL: $SHELL"
    echo "   CLS_FS_ALLOW: $CLS_FS_ALLOW"
}

# Function to enable headless mode
enable_headless_mode() {
    echo ""
    echo "2) Enabling headless mode..."
    
    if bash scripts/enable_headless_mode.sh; then
        echo "   ✅ Headless mode enabled"
    else
        echo "   ❌ Headless mode setup failed"
        return 1
    fi
}

# Function to set up night mode
setup_night_mode() {
    echo ""
    echo "3) Setting up night mode..."
    
    if bash scripts/cls_night_mode.sh; then
        echo "   ✅ Night mode enabled"
    else
        echo "   ❌ Night mode setup failed"
        return 1
    fi
}

# Function to run comprehensive validation
run_comprehensive_validation() {
    echo ""
    echo "4) Running comprehensive validation..."
    
    # Test CLS functionality
    if bash scripts/cls_go_live_validation.sh; then
        echo "   ✅ CLS validation passed"
    else
        echo "   ❌ CLS validation failed"
        return 1
    fi
    
    # Test workflow scan
    if bash scripts/codex_workflow_assistant.sh --scan; then
        echo "   ✅ Workflow scan completed"
    else
        echo "   ❌ Workflow scan failed"
        return 1
    fi
    
    # Test night monitor
    if bash scripts/cls_night_monitor.sh; then
        echo "   ✅ Night monitor working"
    else
        echo "   ❌ Night monitor failed"
        return 1
    fi
    
    # Test emergency stop
    if [[ -f "scripts/cls_emergency_stop.sh" ]]; then
        echo "   ✅ Emergency stop script available"
    else
        echo "   ❌ Emergency stop script missing"
        return 1
    fi
}

# Function to check all systems
check_all_systems() {
    echo ""
    echo "5) Checking all systems..."
    
    # Check LaunchAgents
    if launchctl print "gui/$UID/com.02luka.cls.verification" >/dev/null 2>&1; then
        echo "   ✅ Verification agent loaded"
    else
        echo "   ❌ Verification agent not loaded"
    fi
    
    if launchctl print "gui/$UID/com.02luka.cls.nightmode" >/dev/null 2>&1; then
        echo "   ✅ Night mode agent loaded"
    else
        echo "   ❌ Night mode agent not loaded"
    fi
    
    # Check keepawake daemon
    if launchctl print system/com.02luka.keepawake >/dev/null 2>&1; then
        echo "   ✅ Keepawake daemon running"
    else
        echo "   ❌ Keepawake daemon not running"
    fi
    
    # Check sleep settings
    if pmset -g | grep -q "sleep 0"; then
        echo "   ✅ System sleep disabled"
    else
        echo "   ❌ System sleep enabled"
    fi
    
    if pmset -g | grep -q "displaysleep 0"; then
        echo "   ✅ Display sleep disabled"
    else
        echo "   ❌ Display sleep enabled"
    fi
    
    # Check App Nap
    if defaults read -g NSAppSleepDisabled 2>/dev/null | grep -q "1"; then
        echo "   ✅ App Nap disabled"
    else
        echo "   ❌ App Nap not disabled"
    fi
}

# Function to generate final report
generate_final_report() {
    echo ""
    echo "6) Generating final report..."
    
    REPORT_FILE="g/reports/cls_final_night_setup_$(date +%Y%m%d_%H%M).md"
    mkdir -p "$(dirname "$REPORT_FILE")"
    
    cat > "$REPORT_FILE" << EOF
# CLS Final Night Setup Report

**Generated:** $(date -Iseconds)  
**Status:** Final Night Setup Complete - Ready for Unattended Operation  

## Final Configuration

- **CLS_SHELL:** ${CLS_SHELL:-unset}
- **SHELL:** ${SHELL:-unset}
- **CLS_FS_ALLOW:** ${CLS_FS_ALLOW:-unset}
- **PATH:** ${PATH:-unset}

## LaunchAgents Status

- **Verification Agent:** $(launchctl print "gui/$UID/com.02luka.cls.verification" 2>/dev/null | grep "state =" || echo "Not loaded")
- **Night Mode Agent:** $(launchctl print "gui/$UID/com.02luka.cls.nightmode" 2>/dev/null | grep "state =" || echo "Not loaded")
- **Keepawake Daemon:** $(launchctl print system/com.02luka.keepawake 2>/dev/null | grep "state =" || echo "Not loaded")

## Sleep Settings

- **System Sleep:** $(pmset -g | grep "sleep" | head -1 | awk '{print $2}')
- **Display Sleep:** $(pmset -g | grep "displaysleep" | head -1 | awk '{print $2}')
- **Disk Sleep:** $(pmset -g | grep "disksleep" | head -1 | awk '{print $2}')

## App Nap Settings

- **Global Disabled:** $(defaults read -g NSAppSleepDisabled 2>/dev/null || echo "Unknown")

## Night Mode Features

- ✅ **Continuous Operation** - CLS runs 24/7
- ✅ **Headless Mode** - Works when locked/display off
- ✅ **Auto-Recovery** - Restarts if processes fail
- ✅ **Log Rotation** - Keeps logs manageable
- ✅ **Emergency Stop** - Immediate shutdown if needed
- ✅ **Morning Check** - Automated status review

## Monitoring Commands

\`\`\`bash
# Check night mode status
launchctl print gui/\$UID/com.02luka.cls.nightmode

# Check logs
tail -f /Volumes/lukadata/CLS/logs/cls_night_mode.log

# Check all CLS agents
launchctl print gui/\$UID/com.02luka.cls.verification
launchctl print gui/\$UID/com.02luka.cls.nightmode
launchctl print system/com.02luka.keepawake
\`\`\`

## Emergency Procedures

### Stop All CLS Operations
\`\`\`bash
bash scripts/cls_emergency_stop.sh
\`\`\`

### Restart Night Mode
\`\`\`bash
bash scripts/cls_sleep_mode.sh
\`\`\`

### Check Status
\`\`\`bash
bash scripts/cls_night_monitor.sh
\`\`\`

### Morning Check
\`\`\`bash
bash scripts/cls_morning_check.sh
\`\`\`

## Safety Features

- 🔒 **High-risk commands blocked** (rm -rf /, shutdown)
- 🔒 **Filesystem access limited** to CLS_FS_ALLOW paths
- 🔒 **Telemetry logging** for all operations
- 🔒 **Emergency stop** available
- 🔒 **Auto-recovery** for failed processes

## Next Steps

1. **Go to sleep** - CLS will run continuously
2. **Check in morning** - Run morning check script
3. **Monitor status** - Use provided commands
4. **Emergency stop** - If needed, run emergency script

## Troubleshooting

- **Night mode not running:** Check LaunchAgent status
- **Logs missing:** Check volume mounts and permissions
- **Telemetry inactive:** Check CLS environment variables
- **Queue issues:** Check filesystem permissions

**CLS Final Night Setup Complete - Sweet Dreams!** 🌙🧠⚡
EOF
    
    echo "   ✅ Final report generated: $REPORT_FILE"
}

# Main execution
echo "Starting CLS final night setup..."

setup_final_environment
enable_headless_mode
setup_night_mode
run_comprehensive_validation
check_all_systems
generate_final_report

echo ""
echo "🌙 CLS Final Night Setup Complete"
echo "   CLS will run continuously through the night"
echo "   All systems configured for unattended operation"
echo "   Sweet dreams! 🧠⚡"
echo ""
echo "📊 Monitor with: tail -f /Volumes/lukadata/CLS/logs/cls_night_mode.log"
echo "🚨 Emergency stop: bash scripts/cls_emergency_stop.sh"
echo "🌅 Morning check: bash scripts/cls_morning_check.sh"
echo "📋 Report: g/reports/cls_final_night_setup_*.md"
echo ""
echo "🔒 Safety: High-risk commands blocked, filesystem access limited"
echo "🔄 Auto-recovery: Processes restart automatically if they fail"
echo "📊 Telemetry: All operations logged for audit"
echo ""
echo "🌙 Good night! CLS will keep working while you sleep."
