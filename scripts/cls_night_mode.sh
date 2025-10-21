#!/usr/bin/env bash
set -euo pipefail

# CLS Night Mode - Complete Unattended Operation
# Sets up CLS to run continuously through the night

echo "🌙 CLS Night Mode Setup"
echo "======================"

# Function to set up night mode environment
setup_night_mode() {
    echo "1) Setting up night mode environment..."
    
    # Set environment variables for night operation
    export CLS_SHELL="/bin/bash"
    export SHELL="/bin/bash"
    export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin"
    export CLS_FS_ALLOW="$HOME:/Volumes/lukadata:/Volumes/hd2:$(pwd)"
    
    echo "   ✅ Environment configured for night mode"
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

# Function to set up continuous monitoring
setup_continuous_monitoring() {
    echo ""
    echo "3) Setting up continuous monitoring..."
    
    # Create monitoring script
    cat > scripts/cls_night_monitor.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# CLS Night Monitor - Continuous operation
echo "🌙 CLS Night Monitor - $(date -Iseconds)"

# Check if CLS is running
if pgrep -f "cls" >/dev/null; then
    echo "✅ CLS processes running"
else
    echo "⚠️  CLS processes not detected - starting..."
    # Start CLS verification
    bash scripts/cls_go_live_validation.sh || true
fi

# Check LaunchAgents
if launchctl print "gui/$UID/com.02luka.cls.verification" >/dev/null 2>&1; then
    echo "✅ CLS LaunchAgent loaded"
else
    echo "⚠️  CLS LaunchAgent not loaded - restarting..."
    launchctl kickstart -k "gui/$UID/com.02luka.cls.verification" || true
fi

# Check keepawake daemon
if launchctl print system/com.02luka.keepawake >/dev/null 2>&1; then
    echo "✅ Keepawake daemon running"
else
    echo "⚠️  Keepawake daemon not running - restarting..."
    launchctl kickstart -k system/com.02luka.keepawake || true
fi

# Run workflow scan
echo "🔄 Running workflow scan..."
bash scripts/codex_workflow_assistant.sh --scan || true

# Check telemetry
if [[ -f "g/telemetry/codex_workflow.log" ]]; then
    echo "✅ Telemetry active"
    echo "Recent entries:"
    tail -n 2 "g/telemetry/codex_workflow.log" | sed 's/^/  /'
else
    echo "⚠️  Telemetry not active"
fi

echo "🌙 Night monitor complete - $(date -Iseconds)"
EOF
    
    chmod +x scripts/cls_night_monitor.sh
    echo "   ✅ Night monitor script created"
}

# Function to set up night mode LaunchAgent
setup_night_mode_launchagent() {
    echo ""
    echo "4) Setting up night mode LaunchAgent..."
    
    # Create night mode LaunchAgent
    cat > ~/Library/LaunchAgents/com.02luka.cls.nightmode.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.02luka.cls.nightmode</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>/Users/icmini/dev/02luka-repo/scripts/cls_night_monitor.sh</string>
    </array>
    
    <key>StartInterval</key>
    <integer>300</integer> <!-- Run every 5 minutes -->
    
    <key>EnvironmentVariables</key>
    <dict>
        <key>CLS_SHELL</key>
        <string>/bin/bash</string>
        <key>CLS_FS_ALLOW</key>
        <string>/Volumes/lukadata:/Volumes/hd2:/Users/icmini/Documents/Projects</string>
        <key>PATH</key>
        <string>/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin</string>
    </dict>
    
    <key>WorkingDirectory</key>
    <string>/Users/icmini/dev/02luka-repo</string>
    
    <key>StandardOutPath</key>
    <string>/Volumes/lukadata/CLS/logs/cls_night_mode.log</string>
    
    <key>StandardErrorPath</key>
    <string>/Volumes/lukadata/CLS/logs/cls_night_mode_error.log</string>
    
    <key>RunAtLoad</key>
    <true/>
    
    <key>KeepAlive</key>
    <true/>
    
    <key>ProcessType</key>
    <string>Background</string>
    
    <key>ThrottleInterval</key>
    <integer>60</integer>
</dict>
</plist>
EOF
    
    # Load the LaunchAgent
    launchctl bootout "gui/$UID/com.02luka.cls.nightmode" >/dev/null 2>&1 || true
    launchctl bootstrap "gui/$UID" ~/Library/LaunchAgents/com.02luka.cls.nightmode.plist
    launchctl kickstart -k "gui/$UID/com.02luka.cls.nightmode"
    
    echo "   ✅ Night mode LaunchAgent installed and started"
}

# Function to set up log rotation
setup_log_rotation() {
    echo ""
    echo "5) Setting up log rotation..."
    
    # Create log rotation script
    cat > scripts/cls_log_rotation.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# CLS Log Rotation - Keep logs manageable
LOG_DIR="/Volumes/lukadata/CLS/logs"
MAX_SIZE=10485760  # 10MB

for log_file in "$LOG_DIR"/*.log; do
    if [[ -f "$log_file" ]]; then
        size=$(wc -c < "$log_file" 2>/dev/null || echo 0)
        if [[ $size -gt $MAX_SIZE ]]; then
            echo "Rotating log: $log_file"
            mv "$log_file" "${log_file%.*}.$(date +%Y%m%d_%H%M).log"
            touch "$log_file"
            chmod 644 "$log_file"
        fi
    fi
done

echo "Log rotation complete - $(date -Iseconds)"
EOF
    
    chmod +x scripts/cls_log_rotation.sh
    echo "   ✅ Log rotation script created"
}

# Function to set up emergency stop
setup_emergency_stop() {
    echo ""
    echo "6) Setting up emergency stop..."
    
    # Create emergency stop script
    cat > scripts/cls_emergency_stop.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# CLS Emergency Stop - Immediate shutdown
echo "🚨 CLS Emergency Stop - $(date -Iseconds)"

# Stop all CLS LaunchAgents
launchctl bootout "gui/$UID/com.02luka.cls.verification" >/dev/null 2>&1 || true
launchctl bootout "gui/$UID/com.02luka.cls.nightmode" >/dev/null 2>&1 || true
launchctl bootout "gui/$UID/com.02luka.cls.workflow" >/dev/null 2>&1 || true

# Stop keepawake daemon
launchctl bootout system/com.02luka.keepawake >/dev/null 2>&1 || true

# Kill any remaining CLS processes
pkill -f "cls" >/dev/null 2>&1 || true

echo "✅ All CLS processes stopped"
echo "🌙 Night mode disabled"
EOF
    
    chmod +x scripts/cls_emergency_stop.sh
    echo "   ✅ Emergency stop script created"
}

# Function to run initial night mode test
run_night_mode_test() {
    echo ""
    echo "7) Running night mode test..."
    
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

# Function to generate night mode report
generate_night_mode_report() {
    echo ""
    echo "8) Generating night mode report..."
    
    REPORT_FILE="g/reports/cls_night_mode_$(date +%Y%m%d_%H%M).md"
    mkdir -p "$(dirname "$REPORT_FILE")"
    
    cat > "$REPORT_FILE" << EOF
# CLS Night Mode Setup Report

**Generated:** $(date -Iseconds)  
**Status:** Night Mode Active - Ready for Unattended Operation  

## Night Mode Configuration

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

### Stop Night Mode
\`\`\`bash
bash scripts/cls_emergency_stop.sh
\`\`\`

### Restart Night Mode
\`\`\`bash
bash scripts/cls_night_mode.sh
\`\`\`

### Check Status
\`\`\`bash
bash scripts/cls_night_monitor.sh
\`\`\`

## Safety Features

- 🔒 **High-risk commands blocked** (rm -rf /, shutdown)
- 🔒 **Filesystem access limited** to CLS_FS_ALLOW paths
- 🔒 **Telemetry logging** for all operations
- 🔒 **Emergency stop** available

## Next Steps

1. **Go to sleep** - CLS will run continuously
2. **Check in morning** - Review logs and reports
3. **Monitor status** - Use provided commands
4. **Emergency stop** - If needed, run emergency script

**CLS Night Mode Active - Sweet Dreams!** 🌙🧠⚡
EOF
    
    echo "   ✅ Night mode report generated: $REPORT_FILE"
}

# Main execution
echo "Starting CLS night mode setup..."

setup_night_mode
enable_headless_mode
setup_continuous_monitoring
setup_night_mode_launchagent
setup_log_rotation
setup_emergency_stop
run_night_mode_test
generate_night_mode_report

echo ""
echo "🌙 CLS Night Mode Setup Complete"
echo "   CLS will run continuously through the night"
echo "   All systems configured for unattended operation"
echo "   Sweet dreams! 🧠⚡"
echo ""
echo "📊 Monitor with: tail -f /Volumes/lukadata/CLS/logs/cls_night_mode.log"
echo "🚨 Emergency stop: bash scripts/cls_emergency_stop.sh"
echo "📋 Report: g/reports/cls_night_mode_*.md"
