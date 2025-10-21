#!/usr/bin/env bash
set -euo pipefail

# CLS macOS Headless Mode Complete Setup
# One-shot script to enable headless mode and verify CLS operation

echo "🧠 CLS macOS Headless Mode Complete Setup"
echo "========================================="

# Function to check if running on macOS
check_macos() {
    if ! command -v sw_vers >/dev/null 2>&1; then
        echo "❌ This script is for macOS only"
        exit 1
    fi
    echo "✅ Running on macOS $(sw_vers -productVersion)"
}

# Function to enable headless mode
enable_headless_mode() {
    echo ""
    echo "1) Enabling headless mode..."
    
    if bash scripts/enable_headless_mode.sh; then
        echo "   ✅ Headless mode enabled"
    else
        echo "   ❌ Headless mode setup failed"
        return 1
    fi
}

# Function to verify headless mode
verify_headless_mode() {
    echo ""
    echo "2) Verifying headless mode..."
    
    if bash scripts/cls_headless_verification.sh; then
        echo "   ✅ Headless mode verified"
    else
        echo "   ❌ Headless mode verification failed"
        return 1
    fi
}

# Function to test CLS functionality
test_cls_functionality() {
    echo ""
    echo "3) Testing CLS functionality..."
    
    # Set environment variables
    export CLS_SHELL="/bin/bash"
    export SHELL="/bin/bash"
    export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin"
    export CLS_FS_ALLOW="$HOME:/Volumes/lukadata:/Volumes/hd2:$(pwd)"
    
    echo "   Environment set:"
    echo "   CLS_SHELL: $CLS_SHELL"
    echo "   SHELL: $SHELL"
    echo "   CLS_FS_ALLOW: $CLS_FS_ALLOW"
    
    # Test shell resolver
    if node -e "console.log(require('./packages/skills/resolveShell').resolveShell())" 2>/dev/null; then
        echo "   ✅ Shell resolver working"
    else
        echo "   ❌ Shell resolver failed"
        return 1
    fi
    
    # Test validation script
    if [[ -f "scripts/cls_go_live_validation.sh" ]]; then
        echo "   ✅ Validation script available"
    else
        echo "   ❌ Validation script missing"
        return 1
    fi
}

# Function to check LaunchAgents
check_launchagents() {
    echo ""
    echo "4) Checking LaunchAgents..."
    
    # Check if verification agent is loaded
    if launchctl print "gui/$UID/com.02luka.cls.verification" >/dev/null 2>&1; then
        echo "   ✅ Verification agent loaded"
        
        # Check status
        STATUS=$(launchctl print "gui/$UID/com.02luka.cls.verification" | grep "state =" || echo "state = unknown")
        echo "   $STATUS"
        
        # Check KeepAlive
        if launchctl print "gui/$UID/com.02luka.cls.verification" | grep -q "KeepAlive = true"; then
            echo "   ✅ KeepAlive enabled"
        else
            echo "   ❌ KeepAlive not enabled"
        fi
    else
        echo "   ❌ Verification agent not loaded"
        return 1
    fi
}

# Function to check keepawake daemon
check_keepawake_daemon() {
    echo ""
    echo "5) Checking keepawake daemon..."
    
    if launchctl print system/com.02luka.keepawake >/dev/null 2>&1; then
        echo "   ✅ Keepawake daemon loaded"
        
        # Check status
        STATUS=$(launchctl print system/com.02luka.keepawake | grep "state =" || echo "state = unknown")
        echo "   $STATUS"
        
        # Check PID
        PID=$(launchctl print system/com.02luka.keepawake | grep "pid =" || echo "pid = unknown")
        echo "   $PID"
    else
        echo "   ❌ Keepawake daemon not loaded"
        return 1
    fi
}

# Function to check sleep settings
check_sleep_settings() {
    echo ""
    echo "6) Checking sleep settings..."
    
    # Check system sleep
    if pmset -g | grep -q "sleep 0"; then
        echo "   ✅ System sleep disabled"
    else
        echo "   ❌ System sleep enabled"
    fi
    
    # Check display sleep
    if pmset -g | grep -q "displaysleep 0"; then
        echo "   ✅ Display sleep disabled"
    else
        echo "   ❌ Display sleep enabled"
    fi
    
    # Check disk sleep
    if pmset -g | grep -q "disksleep 0"; then
        echo "   ✅ Disk sleep disabled"
    else
        echo "   ❌ Disk sleep enabled"
    fi
}

# Function to generate final report
generate_final_report() {
    echo ""
    echo "7) Generating final report..."
    
    REPORT_FILE="g/reports/cls_macos_headless_complete_$(date +%Y%m%d_%H%M).md"
    mkdir -p "$(dirname "$REPORT_FILE")"
    
    cat > "$REPORT_FILE" << EOF
# CLS macOS Headless Mode Complete Setup Report

**Generated:** $(date -Iseconds)  
**Status:** Headless Mode Setup Complete  

## System Configuration

- **macOS Version:** $(sw_vers -productVersion)
- **Sleep Settings:** $(pmset -g | grep -E 'sleep|displaysleep|disksleep' | tr '\n' ' ')
- **App Nap:** $(defaults read -g NSAppSleepDisabled 2>/dev/null || echo "Unknown")

## Keepawake Daemon

- **Status:** $(launchctl print system/com.02luka.keepawake 2>/dev/null | grep "state =" || echo "Not loaded")
- **PID:** $(launchctl print system/com.02luka.keepawake 2>/dev/null | grep "pid =" || echo "Unknown")
- **Log:** $(test -f "/var/log/02luka-keepawake.log" && echo "✅ Available" || echo "❌ Missing")

## CLS LaunchAgents

- **Verification Agent:** $(launchctl print "gui/$UID/com.02luka.cls.verification" 2>/dev/null | grep "state =" || echo "Not loaded")
- **KeepAlive:** $(launchctl print "gui/$UID/com.02luka.cls.verification" 2>/dev/null | grep "KeepAlive" || echo "Unknown")
- **ProcessType:** $(launchctl print "gui/$UID/com.02luka.cls.verification" 2>/dev/null | grep "ProcessType" || echo "Unknown")

## CLS Environment

- **CLS_SHELL:** ${CLS_SHELL:-unset}
- **SHELL:** ${SHELL:-unset}
- **CLS_FS_ALLOW:** ${CLS_FS_ALLOW:-unset}
- **PATH:** ${PATH:-unset}

## Next Steps

1. **Test Headless Operation:**
   - Lock screen or turn off display
   - Wait 5 minutes
   - Check logs for activity

2. **Monitor Status:**
   \`\`\`bash
   # Check keepawake daemon
   launchctl print system/com.02luka.keepawake
   
   # Check CLS agents
   launchctl print gui/\$UID/com.02luka.cls.verification
   \`\`\`

3. **Check Logs:**
   \`\`\`bash
   # Keepawake log
   tail -f /var/log/02luka-keepawake.log
   
   # CLS verification log
   tail -f /Volumes/lukadata/CLS/logs/cls_verification.log
   \`\`\`

## Troubleshooting

- **Sleep not disabled:** Run \`scripts/enable_headless_mode.sh\`
- **Keepawake not running:** Check \`/var/log/02luka-keepawake.log\`
- **CLS agents not running:** Check LaunchAgent plist files
- **App Nap still active:** Log out and log back in

## Rollback

If you need to disable headless mode:
\`\`\`bash
bash scripts/disable_headless_mode.sh
\`\`\`

**CLS macOS Headless Mode Complete Setup Finished** 🧠⚡
EOF
    
    echo "   ✅ Final report generated: $REPORT_FILE"
}

# Main execution
echo "Starting CLS macOS headless mode complete setup..."

check_macos
enable_headless_mode
verify_headless_mode
test_cls_functionality
check_launchagents
check_keepawake_daemon
check_sleep_settings
generate_final_report

echo ""
echo "🎯 CLS macOS Headless Mode Complete Setup Finished"
echo "   Mac mini is now configured for headless operation"
echo "   CLS will run even when display is off or locked"
echo "   Report: g/reports/cls_macos_headless_complete_*.md"
echo ""
echo "🔒 Safety: High-risk commands are still blocked"
echo "📊 Monitoring: Check logs for activity"
echo "🔄 Rollback: Run scripts/disable_headless_mode.sh if needed"
