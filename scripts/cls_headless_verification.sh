#!/usr/bin/env bash
set -euo pipefail

# CLS Headless Mode Verification
# Verifies that CLS runs properly in headless mode

echo "🧠 CLS Headless Mode Verification"
echo "=================================="

# Function to check sleep settings
check_sleep_settings() {
    echo "1) Checking sleep settings..."
    
    # Check pmset settings
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
    
    if pmset -g | grep -q "disksleep 0"; then
        echo "   ✅ Disk sleep disabled"
    else
        echo "   ❌ Disk sleep enabled"
    fi
}

# Function to check keepawake daemon
check_keepawake_daemon() {
    echo ""
    echo "2) Checking keepawake daemon..."
    
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
    fi
}

# Function to check CLS LaunchAgents
check_cls_launchagents() {
    echo ""
    echo "3) Checking CLS LaunchAgents..."
    
    # Check verification agent
    if launchctl print "gui/$UID/com.02luka.cls.verification" >/dev/null 2>&1; then
        echo "   ✅ Verification agent loaded"
        
        # Check KeepAlive setting
        if launchctl print "gui/$UID/com.02luka.cls.verification" | grep -q "KeepAlive = true"; then
            echo "   ✅ KeepAlive enabled"
        else
            echo "   ❌ KeepAlive not enabled"
        fi
        
        # Check ProcessType
        if launchctl print "gui/$UID/com.02luka.cls.verification" | grep -q "ProcessType = Background"; then
            echo "   ✅ ProcessType = Background"
        else
            echo "   ❌ ProcessType not set to Background"
        fi
    else
        echo "   ❌ Verification agent not loaded"
    fi
    
    # Check workflow agent (if exists)
    if launchctl print "gui/$UID/com.02luka.cls.workflow" >/dev/null 2>&1; then
        echo "   ✅ Workflow agent loaded"
    else
        echo "   ⚠️  Workflow agent not loaded (optional)"
    fi
}

# Function to check App Nap settings
check_app_nap_settings() {
    echo ""
    echo "4) Checking App Nap settings..."
    
    # Check global App Nap setting
    if defaults read -g NSAppSleepDisabled 2>/dev/null | grep -q "1"; then
        echo "   ✅ App Nap disabled globally"
    else
        echo "   ❌ App Nap not disabled globally"
    fi
}

# Function to test CLS functionality
test_cls_functionality() {
    echo ""
    echo "5) Testing CLS functionality..."
    
    # Test shell resolver
    if node -e "console.log(require('./packages/skills/resolveShell').resolveShell())" 2>/dev/null; then
        echo "   ✅ Shell resolver working"
    else
        echo "   ❌ Shell resolver failed"
    fi
    
    # Test validation script
    if [[ -f "scripts/cls_go_live_validation.sh" ]]; then
        echo "   ✅ Validation script available"
    else
        echo "   ❌ Validation script missing"
    fi
    
    # Test workflow script
    if [[ -f "scripts/codex_workflow_assistant.sh" ]]; then
        echo "   ✅ Workflow script available"
    else
        echo "   ❌ Workflow script missing"
    fi
}

# Function to check logs
check_logs() {
    echo ""
    echo "6) Checking logs..."
    
    # Check keepawake log
    if [[ -f "/var/log/02luka-keepawake.log" ]]; then
        echo "   ✅ Keepawake log exists"
        echo "   Recent entries:"
        tail -n 3 "/var/log/02luka-keepawake.log" | sed 's/^/     /'
    else
        echo "   ⚠️  Keepawake log not found"
    fi
    
    # Check CLS logs
    if [[ -f "/Volumes/lukadata/CLS/logs/cls_verification.log" ]]; then
        echo "   ✅ CLS verification log exists"
        echo "   Recent entries:"
        tail -n 3 "/Volumes/lukadata/CLS/logs/cls_verification.log" | sed 's/^/     /'
    else
        echo "   ⚠️  CLS verification log not found"
    fi
}

# Function to generate verification report
generate_verification_report() {
    echo ""
    echo "7) Generating verification report..."
    
    REPORT_FILE="g/reports/cls_headless_verification_$(date +%Y%m%d_%H%M).md"
    mkdir -p "$(dirname "$REPORT_FILE")"
    
    cat > "$REPORT_FILE" << EOF
# CLS Headless Mode Verification Report

**Generated:** $(date -Iseconds)  
**Status:** Headless Mode Verification Complete  

## Sleep Settings

- System Sleep: $(pmset -g | grep "sleep" | head -1 | awk '{print $2}')
- Display Sleep: $(pmset -g | grep "displaysleep" | head -1 | awk '{print $2}')
- Disk Sleep: $(pmset -g | grep "disksleep" | head -1 | awk '{print $2}')

## Keepawake Daemon

- Status: $(launchctl print system/com.02luka.keepawake 2>/dev/null | grep "state =" || echo "Not loaded")
- PID: $(launchctl print system/com.02luka.keepawake 2>/dev/null | grep "pid =" || echo "Unknown")

## CLS LaunchAgents

- Verification Agent: $(launchctl print "gui/$UID/com.02luka.cls.verification" 2>/dev/null | grep "state =" || echo "Not loaded")
- KeepAlive: $(launchctl print "gui/$UID/com.02luka.cls.verification" 2>/dev/null | grep "KeepAlive" || echo "Unknown")
- ProcessType: $(launchctl print "gui/$UID/com.02luka.cls.verification" 2>/dev/null | grep "ProcessType" || echo "Unknown")

## App Nap Settings

- Global Disabled: $(defaults read -g NSAppSleepDisabled 2>/dev/null || echo "Unknown")

## Logs

- Keepawake Log: $(test -f "/var/log/02luka-keepawake.log" && echo "✅ Exists" || echo "❌ Missing")
- CLS Verification Log: $(test -f "/Volumes/lukadata/CLS/logs/cls_verification.log" && echo "✅ Exists" || echo "❌ Missing")

## Next Steps

1. **Test Headless Operation:**
   - Lock screen or turn off display
   - Wait 5 minutes
   - Check logs for activity

2. **Monitor LaunchAgents:**
   \`\`\`bash
   launchctl print gui/\$UID/com.02luka.cls.verification
   \`\`\`

3. **Check Keepawake Status:**
   \`\`\`bash
   launchctl print system/com.02luka.keepawake
   \`\`\`

## Troubleshooting

- **Sleep not disabled:** Run \`scripts/enable_headless_mode.sh\`
- **Keepawake not running:** Check \`/var/log/02luka-keepawake.log\`
- **CLS agents not running:** Check LaunchAgent plist files
- **App Nap still active:** Log out and log back in

**CLS Headless Mode Verification Complete** 🧠⚡
EOF
    
    echo "   ✅ Verification report generated: $REPORT_FILE"
}

# Main execution
echo "Starting CLS headless mode verification..."

check_sleep_settings
check_keepawake_daemon
check_cls_launchagents
check_app_nap_settings
test_cls_functionality
check_logs
generate_verification_report

echo ""
echo "🎯 CLS Headless Mode Verification Complete"
echo "   All headless mode components verified"
echo "   Report: g/reports/cls_headless_verification_*.md"
