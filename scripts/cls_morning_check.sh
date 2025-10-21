#!/usr/bin/env bash
set -euo pipefail

# CLS Morning Check - Review night mode operation
# Run this when you wake up to check how CLS performed

echo "🌅 CLS Morning Check"
echo "==================="

# Function to check night mode status
check_night_mode_status() {
    echo "1) Checking night mode status..."
    
    # Check LaunchAgents
    if launchctl print "gui/$UID/com.02luka.cls.nightmode" >/dev/null 2>&1; then
        echo "   ✅ Night mode agent loaded"
        STATUS=$(launchctl print "gui/$UID/com.02luka.cls.nightmode" | grep "state =" || echo "state = unknown")
        echo "   $STATUS"
    else
        echo "   ❌ Night mode agent not loaded"
    fi
    
    # Check verification agent
    if launchctl print "gui/$UID/com.02luka.cls.verification" >/dev/null 2>&1; then
        echo "   ✅ Verification agent loaded"
    else
        echo "   ❌ Verification agent not loaded"
    fi
    
    # Check keepawake daemon
    if launchctl print system/com.02luka.keepawake >/dev/null 2>&1; then
        echo "   ✅ Keepawake daemon running"
    else
        echo "   ❌ Keepawake daemon not running"
    fi
}

# Function to check logs
check_logs() {
    echo ""
    echo "2) Checking logs..."
    
    # Check night mode log
    if [[ -f "/Volumes/lukadata/CLS/logs/cls_night_mode.log" ]]; then
        echo "   ✅ Night mode log exists"
        echo "   Recent entries:"
        tail -n 5 "/Volumes/lukadata/CLS/logs/cls_night_mode.log" | sed 's/^/     /'
    else
        echo "   ❌ Night mode log not found"
    fi
    
    # Check verification log
    if [[ -f "/Volumes/lukadata/CLS/logs/cls_verification.log" ]]; then
        echo "   ✅ Verification log exists"
        echo "   Recent entries:"
        tail -n 3 "/Volumes/lukadata/CLS/logs/cls_verification.log" | sed 's/^/     /'
    else
        echo "   ⚠️  Verification log not found"
    fi
    
    # Check keepawake log
    if [[ -f "/var/log/02luka-keepawake.log" ]]; then
        echo "   ✅ Keepawake log exists"
        echo "   Recent entries:"
        tail -n 3 "/var/log/02luka-keepawake.log" | sed 's/^/     /'
    else
        echo "   ⚠️  Keepawake log not found"
    fi
}

# Function to check telemetry
check_telemetry() {
    echo ""
    echo "3) Checking telemetry..."
    
    # Check workflow telemetry
    if [[ -f "g/telemetry/codex_workflow.log" ]]; then
        echo "   ✅ Workflow telemetry active"
        echo "   Recent entries:"
        tail -n 3 "g/telemetry/codex_workflow.log" | sed 's/^/     /'
    else
        echo "   ⚠️  Workflow telemetry not found"
    fi
    
    # Check CLS telemetry
    if [[ -f "g/telemetry/cls_runs.ndjson" ]]; then
        echo "   ✅ CLS telemetry active"
        echo "   Recent entries:"
        tail -n 2 "g/telemetry/cls_runs.ndjson" | sed 's/^/     /'
    else
        echo "   ⚠️  CLS telemetry not found"
    fi
}

# Function to check queue status
check_queue_status() {
    echo ""
    echo "4) Checking queue status..."
    
    if [[ -d "queue" ]]; then
        echo "   ✅ Queue directory exists"
        
        # Check inbox
        if [[ -d "queue/inbox" ]]; then
            INBOX_COUNT=$(ls queue/inbox/ 2>/dev/null | wc -l)
            echo "   📥 Inbox: $INBOX_COUNT tasks"
        fi
        
        # Check done
        if [[ -d "queue/done" ]]; then
            DONE_COUNT=$(ls queue/done/ 2>/dev/null | wc -l)
            echo "   ✅ Done: $DONE_COUNT tasks"
        fi
        
        # Check failed
        if [[ -d "queue/failed" ]]; then
            FAILED_COUNT=$(ls queue/failed/ 2>/dev/null | wc -l)
            echo "   ❌ Failed: $FAILED_COUNT tasks"
        fi
    else
        echo "   ⚠️  Queue directory not found"
    fi
}

# Function to check reports
check_reports() {
    echo ""
    echo "5) Checking reports..."
    
    if [[ -d "g/reports" ]]; then
        echo "   ✅ Reports directory exists"
        
        # Count reports from last 24 hours
        RECENT_REPORTS=$(find g/reports -name "*.md" -mtime -1 2>/dev/null | wc -l)
        echo "   📊 Recent reports (24h): $RECENT_REPORTS"
        
        # List recent reports
        if [[ $RECENT_REPORTS -gt 0 ]]; then
            echo "   Recent reports:"
            find g/reports -name "*.md" -mtime -1 2>/dev/null | head -5 | sed 's/^/     /'
        fi
    else
        echo "   ⚠️  Reports directory not found"
    fi
}

# Function to run morning validation
run_morning_validation() {
    echo ""
    echo "6) Running morning validation..."
    
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
}

# Function to generate morning report
generate_morning_report() {
    echo ""
    echo "7) Generating morning report..."
    
    REPORT_FILE="g/reports/cls_morning_check_$(date +%Y%m%d_%H%M).md"
    mkdir -p "$(dirname "$REPORT_FILE")"
    
    cat > "$REPORT_FILE" << EOF
# CLS Morning Check Report

**Generated:** $(date -Iseconds)  
**Status:** Morning Check Complete  

## Night Mode Status

- **Night Mode Agent:** $(launchctl print "gui/$UID/com.02luka.cls.nightmode" 2>/dev/null | grep "state =" || echo "Not loaded")
- **Verification Agent:** $(launchctl print "gui/$UID/com.02luka.cls.verification" 2>/dev/null | grep "state =" || echo "Not loaded")
- **Keepawake Daemon:** $(launchctl print system/com.02luka.keepawake 2>/dev/null | grep "state =" || echo "Not loaded")

## Logs Status

- **Night Mode Log:** $(test -f "/Volumes/lukadata/CLS/logs/cls_night_mode.log" && echo "✅ Available" || echo "❌ Missing")
- **Verification Log:** $(test -f "/Volumes/lukadata/CLS/logs/cls_verification.log" && echo "✅ Available" || echo "❌ Missing")
- **Keepawake Log:** $(test -f "/var/log/02luka-keepawake.log" && echo "✅ Available" || echo "❌ Missing")

## Telemetry Status

- **Workflow Telemetry:** $(test -f "g/telemetry/codex_workflow.log" && echo "✅ Active" || echo "❌ Inactive")
- **CLS Telemetry:** $(test -f "g/telemetry/cls_runs.ndjson" && echo "✅ Active" || echo "❌ Inactive")

## Queue Status

- **Inbox:** $(ls queue/inbox/ 2>/dev/null | wc -l) tasks
- **Done:** $(ls queue/done/ 2>/dev/null | wc -l) tasks
- **Failed:** $(ls queue/failed/ 2>/dev/null | wc -l) tasks

## Reports Status

- **Recent Reports (24h):** $(find g/reports -name "*.md" -mtime -1 2>/dev/null | wc -l)
- **Total Reports:** $(find g/reports -name "*.md" 2>/dev/null | wc -l)

## Night Mode Performance

- **Uptime:** $(uptime | awk '{print $3,$4}' | sed 's/,//')
- **Load Average:** $(uptime | awk -F'load averages:' '{print $2}')
- **Memory Usage:** $(ps aux | grep -v grep | grep -c "cls" || echo "0") CLS processes

## Next Steps

1. **Review Logs:**
   \`\`\`bash
   tail -f /Volumes/lukadata/CLS/logs/cls_night_mode.log
   \`\`\`

2. **Check Queue:**
   \`\`\`bash
   ls -la queue/done/ queue/failed/
   \`\`\`

3. **Review Reports:**
   \`\`\`bash
   ls -la g/reports/
   \`\`\`

4. **Continue Night Mode:**
   \`\`\`bash
   # Night mode continues automatically
   \`\`\`

5. **Stop Night Mode:**
   \`\`\`bash
   bash scripts/cls_emergency_stop.sh
   \`\`\`

## Troubleshooting

- **Night mode not running:** Check LaunchAgent status
- **Logs missing:** Check volume mounts and permissions
- **Telemetry inactive:** Check CLS environment variables
- **Queue issues:** Check filesystem permissions

**CLS Morning Check Complete** 🌅🧠⚡
EOF
    
    echo "   ✅ Morning report generated: $REPORT_FILE"
}

# Main execution
echo "Starting CLS morning check..."

check_night_mode_status
check_logs
check_telemetry
check_queue_status
check_reports
run_morning_validation
generate_morning_report

echo ""
echo "🌅 CLS Morning Check Complete"
echo "   Night mode operation reviewed"
echo "   All systems checked and validated"
echo "   Report: g/reports/cls_morning_check_*.md"
echo ""
echo "📊 Continue monitoring with: tail -f /Volumes/lukadata/CLS/logs/cls_night_mode.log"
echo "🚨 Emergency stop: bash scripts/cls_emergency_stop.sh"
