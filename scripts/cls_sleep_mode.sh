#!/usr/bin/env bash
set -euo pipefail

# CLS Sleep Mode - Complete Night Operation
# One-shot script to set up CLS for continuous night operation

echo "🌙 CLS Sleep Mode - Complete Night Operation"
echo "============================================="

# Function to set up sleep mode environment
setup_sleep_mode() {
    echo "1) Setting up sleep mode environment..."
    
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

# Function to run final validation
run_final_validation() {
    echo ""
    echo "4) Running final validation..."
    
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
}

# Function to generate sleep mode report
generate_sleep_mode_report() {
    echo ""
    echo "6) Generating sleep mode report..."
    
    REPORT_FILE="g/reports/cls_sleep_mode_$(date +%Y%m%d_%H%M).md"
    mkdir -p "$(dirname "$REPORT_FILE")"
    
    cat > "$REPORT_FILE" << EOF
# CLS Sleep Mode Report

**Generated:** $(date -Iseconds)  
**Status:** Sleep Mode Active - Ready for Night Operation  

## Sleep Mode Configuration

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

## Night Mode Features

- ✅ **Continuous Operation** - CLS runs 24/7
- ✅ **Headless Mode** - Works when locked/display off
- ✅ **Auto-Recovery** - Restarts if processes fail
- ✅ **Log Rotation** - Keeps logs manageable
- ✅ **Emergency Stop** - Immediate shutdown if needed

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

### Stop Sleep Mode
\`\`\`bash
bash scripts/cls_emergency_stop.sh
\`\`\`

### Restart Sleep Mode
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

## Next Steps

1. **Go to sleep** - CLS will run continuously
2. **Check in morning** - Run morning check script
3. **Monitor status** - Use provided commands
4. **Emergency stop** - If needed, run emergency script

**CLS Sleep Mode Active - Sweet Dreams!** 🌙🧠⚡
EOF
    
    echo "   ✅ Sleep mode report generated: $REPORT_FILE"
}

# Main execution
echo "Starting CLS sleep mode setup..."

setup_sleep_mode
enable_headless_mode
setup_night_mode
run_final_validation
check_all_systems
generate_sleep_mode_report

echo ""
echo "🌙 CLS Sleep Mode Setup Complete"
echo "   CLS will run continuously through the night"
echo "   All systems configured for unattended operation"
echo "   Sweet dreams! 🧠⚡"
echo ""
echo "📊 Monitor with: tail -f /Volumes/lukadata/CLS/logs/cls_night_mode.log"
echo "🚨 Emergency stop: bash scripts/cls_emergency_stop.sh"
echo "🌅 Morning check: bash scripts/cls_morning_check.sh"
echo "📋 Report: g/reports/cls_sleep_mode_*.md"
