#!/usr/bin/env bash
set -euo pipefail

# CLS LaunchAgent Validation Script
# Validates plist, loads service, and tests execution

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLIST_FILE="$HOME/Library/LaunchAgents/com.02luka.cls.verification.plist"

echo "🧠 CLS LaunchAgent Validation"
echo "=============================="

# 1. Confirm plist is in the right place and readable
echo "1) Checking plist location and syntax..."
if [[ -f "$PLIST_FILE" ]]; then
    echo "✅ Plist found: $PLIST_FILE"
    ls -l "$PLIST_FILE"
else
    echo "❌ Plist not found: $PLIST_FILE"
    echo "   Run: bash scripts/install_cls_launchagent.sh"
    exit 1
fi

# Validate plist syntax
if plutil -lint "$PLIST_FILE" >/dev/null 2>&1; then
    echo "✅ Plist syntax valid"
else
    echo "❌ Plist syntax invalid"
    plutil -lint "$PLIST_FILE"
    exit 1
fi

# 2. Make sure scripts are executable
echo ""
echo "2) Checking script permissions..."
chmod +x "$REPO_ROOT/scripts/cls_verification_with_upload.sh"
chmod +x "$REPO_ROOT/scripts/cls_go_live_verification.sh"
echo "✅ Scripts made executable"

# 3. Load and kickstart the agent
echo ""
echo "3) Loading LaunchAgent..."
launchctl bootstrap "gui/$UID" "$PLIST_FILE" 2>/dev/null || echo "   (Already loaded)"
launchctl kickstart -k "gui/$UID/com.02luka.cls.verification"
echo "✅ LaunchAgent loaded and started"

# 4. Check service status
echo ""
echo "4) Checking service status..."
launchctl print "gui/$UID/com.02luka.cls.verification" | sed -n '1,20p'

# 5. Test manual execution
echo ""
echo "5) Testing manual execution..."
if bash "$REPO_ROOT/scripts/cls_verification_with_upload.sh"; then
    echo "✅ Manual execution successful"
else
    echo "❌ Manual execution failed"
    exit 1
fi

# 6. Check logs and artifacts
echo ""
echo "6) Checking logs and artifacts..."
LOG_FILE="/Volumes/lukadata/CLS/logs/cls_verification.log"
if [[ -f "$LOG_FILE" ]]; then
    echo "✅ Log file exists: $LOG_FILE"
    echo "   Last 5 lines:"
    tail -n 5 "$LOG_FILE"
else
    echo "⚠️  Log file not found: $LOG_FILE"
fi

REPORT_DIR="/Volumes/lukadata/CLS/reports/"
if [[ -d "$REPORT_DIR" ]]; then
    echo "✅ Reports directory exists: $REPORT_DIR"
    ls -la "$REPORT_DIR" | head -n 5
else
    echo "⚠️  Reports directory not found: $REPORT_DIR"
fi

echo ""
echo "🎯 CLS LaunchAgent Validation Complete"
echo "   Service is loaded and ready for daily execution at 09:00"
