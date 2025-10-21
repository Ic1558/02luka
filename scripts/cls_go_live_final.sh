#!/usr/bin/env bash
set -euo pipefail

# CLS Go-Live Final Validation
# Complete end-to-end test of CLS LaunchAgent

echo "🧠 CLS Go-Live Final Validation"
echo "==============================="

# 0) Ensure scripts are executable
echo "0) Making scripts executable..."
chmod +x scripts/cls_verification_with_upload.sh \
        scripts/cls_go_live_verification.sh \
        scripts/validate_cls_launchagent.sh \
        scripts/uninstall_cls_launchagent.sh
echo "✅ Scripts made executable"

# 1) Load & kickstart the agent
echo ""
echo "1) Loading LaunchAgent..."
launchctl bootout "gui/$UID" ~/Library/LaunchAgents/com.02luka.cls.verification.plist 2>/dev/null || true
launchctl bootstrap "gui/$UID" ~/Library/LaunchAgents/com.02luka.cls.verification.plist
launchctl kickstart -k "gui/$UID/com.02luka.cls.verification"
echo "✅ LaunchAgent loaded and started"

# 2) Check service status
echo ""
echo "2) Checking service status..."
launchctl print "gui/$UID/com.02luka.cls.verification" | grep -E 'LastExitStatus|PID|LastExitTime' || echo "   (Service starting...)"

# 3) Test manual execution
echo ""
echo "3) Testing manual execution..."
if bash scripts/cls_verification_with_upload.sh; then
    echo "✅ Manual execution successful"
else
    echo "❌ Manual execution failed"
    exit 1
fi

# 4) Check logs
echo ""
echo "4) Checking logs..."
LOG_FILE="/Volumes/lukadata/CLS/logs/cls_verification.log"
if [[ -f "$LOG_FILE" ]]; then
    echo "✅ Log file exists: $LOG_FILE"
    echo "   Last 10 lines:"
    tail -n 10 "$LOG_FILE"
else
    echo "⚠️  Log file not found: $LOG_FILE"
fi

# 5) Check reports
echo ""
echo "5) Checking reports..."
REPORT_DIR="/Volumes/lukadata/CLS/reports/"
if [[ -d "$REPORT_DIR" ]]; then
    echo "✅ Reports directory exists: $REPORT_DIR"
    ls -la "$REPORT_DIR" | tail -n 5
else
    echo "⚠️  Reports directory not found: $REPORT_DIR"
fi

# 6) Check telemetry
echo ""
echo "6) Checking telemetry..."
if [[ -d "g/telemetry" ]]; then
    echo "✅ Telemetry directory exists"
    ls -la g/telemetry/ | tail -n 3
else
    echo "⚠️  Telemetry directory not found"
fi

# 7) Check memory
echo ""
echo "7) Checking memory..."
if [[ -f "g/memory/vector_index.json" ]]; then
    echo "✅ Memory index exists"
    if command -v node >/dev/null 2>&1; then
        node memory/index.cjs --stats 2>/dev/null || echo "   (Memory stats not available)"
    fi
else
    echo "⚠️  Memory index not found"
fi

# 8) Final service status
echo ""
echo "8) Final service status..."
launchctl print "gui/$UID/com.02luka.cls.verification" | grep -E 'LastExitStatus|PID|LastExitTime'

echo ""
echo "🎯 CLS Go-Live Final Validation Complete"
echo "   LaunchAgent is loaded and ready for daily execution at 09:00"
echo "   To monitor: tail -f /Volumes/lukadata/CLS/logs/cls_verification.log"
