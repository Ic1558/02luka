#!/usr/bin/env bash
set -euo pipefail

# CLS macOS LaunchAgent Setup
# Installs and configures daily automation

echo "🧠 CLS macOS LaunchAgent Setup"
echo "=============================="

# Function to install LaunchAgent
install_launchagent() {
    echo "1) Installing LaunchAgent..."
    
    if bash scripts/install_cls_launchagent.sh; then
        echo "   ✅ LaunchAgent installed"
    else
        echo "   ❌ LaunchAgent installation failed"
        return 1
    fi
}

# Function to start LaunchAgent
start_launchagent() {
    echo ""
    echo "2) Starting LaunchAgent..."
    
    # Kickstart the service
    if launchctl kickstart -k "gui/$UID/com.02luka.cls.verification"; then
        echo "   ✅ LaunchAgent started"
    else
        echo "   ❌ LaunchAgent start failed"
        return 1
    fi
}

# Function to verify LaunchAgent health
verify_launchagent() {
    echo ""
    echo "3) Verifying LaunchAgent health..."
    
    # Check status
    STATUS=$(launchctl print "gui/$UID/com.02luka.cls.verification" | grep LastExitStatus || echo "LastExitStatus = unknown")
    echo "   Status: $STATUS"
    
    if [[ "$STATUS" == *"LastExitStatus = 0"* ]]; then
        echo "   ✅ LaunchAgent healthy"
    else
        echo "   ⚠️  LaunchAgent status unclear"
    fi
    
    # Check PID
    PID=$(launchctl print "gui/$UID/com.02luka.cls.verification" | grep PID || echo "PID = unknown")
    echo "   $PID"
    
    # Check last exit time
    EXIT_TIME=$(launchctl print "gui/$UID/com.02luka.cls.verification" | grep LastExitTime || echo "LastExitTime = unknown")
    echo "   $EXIT_TIME"
}

# Function to check logs
check_logs() {
    echo ""
    echo "4) Checking logs..."
    
    LOG_FILE="/Volumes/lukadata/CLS/logs/cls_verification.log"
    if [[ -f "$LOG_FILE" ]]; then
        echo "   ✅ Log file exists: $LOG_FILE"
        echo "   Recent entries:"
        tail -n 5 "$LOG_FILE" | sed 's/^/     /'
    else
        echo "   ⚠️  Log file not found: $LOG_FILE"
        echo "   Creating log directory..."
        mkdir -p "$(dirname "$LOG_FILE")"
    fi
}

# Function to test manual run
test_manual_run() {
    echo ""
    echo "5) Testing manual run..."
    
    if bash scripts/cls_go_live_validation.sh; then
        echo "   ✅ Manual run successful"
    else
        echo "   ❌ Manual run failed"
        return 1
    fi
}

# Function to generate status report
generate_status_report() {
    echo ""
    echo "6) Generating status report..."
    
    REPORT_FILE="g/reports/cls_launchagent_status_$(date +%Y%m%d_%H%M).md"
    mkdir -p "$(dirname "$REPORT_FILE")"
    
    cat > "$REPORT_FILE" << EOF
# CLS LaunchAgent Status Report

**Generated:** $(date -Iseconds)  
**Status:** LaunchAgent Configured  

## LaunchAgent Status

- Loaded: $(launchctl list | grep -q com.02luka.cls.verification && echo "✅ Yes" || echo "❌ No")
- Status: $(launchctl print "gui/$UID/com.02luka.cls.verification" | grep LastExitStatus || echo "Unknown")
- PID: $(launchctl print "gui/$UID/com.02luka.cls.verification" | grep PID || echo "Unknown")
- Last Exit: $(launchctl print "gui/$UID/com.02luka.cls.verification" | grep LastExitTime || echo "Unknown")

## Logs

- Log File: $(test -f "/Volumes/lukadata/CLS/logs/cls_verification.log" && echo "✅ Exists" || echo "❌ Missing")
- Recent Entries: $(test -f "/Volumes/lukadata/CLS/logs/cls_verification.log" && echo "✅ Available" || echo "❌ Missing")

## Next Steps

1. **Monitor LaunchAgent:**
   \`\`\`bash
   launchctl print gui/\$UID/com.02luka.cls.verification | grep -E 'LastExitStatus|PID|LastExitTime'
   \`\`\`

2. **Check Logs:**
   \`\`\`bash
   tail -n 100 /Volumes/lukadata/CLS/logs/cls_verification.log
   \`\`\`

3. **Manual Test:**
   \`\`\`bash
   bash scripts/cls_go_live_validation.sh
   \`\`\`

## Troubleshooting

- If LaunchAgent fails: \`launchctl bootout gui/\$UID ~/Library/LaunchAgents/com.02luka.cls.verification.plist\`
- If logs missing: \`mkdir -p /Volumes/lukadata/CLS/logs/\`
- If manual test fails: Check CLS_SHELL and CLS_FS_ALLOW environment variables

**CLS LaunchAgent Status Complete** 🧠⚡
EOF
    
    echo "   ✅ Status report generated: $REPORT_FILE"
}

# Main execution
echo "Starting CLS macOS LaunchAgent setup..."

install_launchagent
start_launchagent
verify_launchagent
check_logs
test_manual_run
generate_status_report

echo ""
echo "🎯 CLS macOS LaunchAgent Setup Complete"
echo "   Daily automation configured and running"
echo "   Monitor with: launchctl print gui/\$UID/com.02luka.cls.verification"
echo "   Logs at: /Volumes/lukadata/CLS/logs/cls_verification.log"
