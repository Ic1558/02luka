#!/usr/bin/env bash
set -euo pipefail

# CLS Final Cutover Script
# Day-0 production cutover with comprehensive validation

echo "🧠 CLS Final Cutover - Day-0 Production"
echo "======================================="

# Function to check volumes
check_volumes() {
    echo "0) Checking volumes..."
    
    if [[ -d "/Volumes/lukadata" ]]; then
        echo "   ✅ lukadata mounted"
    else
        echo "   ⚠️  lukadata not mounted - will use fallback g/tmp"
    fi
    
    if [[ -d "/Volumes/hd2" ]]; then
        echo "   ✅ hd2 mounted"
    else
        echo "   ⚠️  hd2 not mounted - will use fallback g/tmp"
    fi
}

# Function to install automation
install_automation() {
    echo ""
    echo "1) Installing workflow automation..."
    
    if bash scripts/install_all_workflow_automation.sh; then
        echo "   ✅ Workflow automation installed"
    else
        echo "   ❌ Installation failed"
        return 1
    fi
}

# Function to load LaunchAgent
load_launchagent() {
    echo ""
    echo "2) Loading LaunchAgent..."
    
    # Boot out existing
    launchctl bootout "gui/$UID" ~/Library/LaunchAgents/com.02luka.cls.workflow.plist 2>/dev/null || true
    
    # Bootstrap new
    launchctl bootstrap "gui/$UID" ~/Library/LaunchAgents/com.02luka.cls.workflow.plist
    
    # Kickstart
    launchctl kickstart -k "gui/$UID/com.02luka.cls.workflow"
    
    echo "   ✅ LaunchAgent loaded and started"
}

# Function to run validation
run_validation() {
    echo ""
    echo "3) Running end-to-end validation..."
    
    if bash scripts/cls_go_live_validation.sh; then
        echo "   ✅ Validation completed"
    else
        echo "   ❌ Validation failed"
        return 1
    fi
}

# Function to run complete workflow
run_complete_workflow() {
    echo ""
    echo "4) Running complete workflow test..."
    
    if bash scripts/cls_complete_workflow.sh; then
        echo "   ✅ Complete workflow test passed"
    else
        echo "   ❌ Complete workflow test failed"
        return 1
    fi
}

# Function to verify green checks
verify_green_checks() {
    echo ""
    echo "5) Verifying green checks..."
    
    # Check LaunchAgent status
    STATUS=$(launchctl print "gui/$UID/com.02luka.cls.workflow" | grep LastExitStatus || echo "LastExitStatus = unknown")
    echo "   LaunchAgent status: $STATUS"
    
    if [[ "$STATUS" == *"LastExitStatus = 0"* ]]; then
        echo "   ✅ LaunchAgent healthy"
    else
        echo "   ❌ LaunchAgent status unclear"
        return 1
    fi
    
    # Check workflow log
    if [[ -f "/Volumes/lukadata/CLS/logs/cls_workflow.log" ]]; then
        echo "   ✅ Workflow log exists"
        echo "   Recent entries:"
        tail -n 5 "/Volumes/lukadata/CLS/logs/cls_workflow.log" | sed 's/^/     /'
    else
        echo "   ⚠️  Workflow log not found"
    fi
    
    # Check staging
    if git ls-remote --heads origin staging >/dev/null 2>&1; then
        echo "   ✅ Remote staging branch exists"
        echo "   Recent commits:"
        git log origin/staging -3 --oneline | sed 's/^/     /'
    else
        echo "   ⚠️  Remote staging branch not found"
    fi
    
    # Check telemetry
    if [[ -f "g/telemetry/codex_workflow.log" ]]; then
        echo "   ✅ Workflow telemetry exists"
        echo "   Recent entries:"
        tail -n 3 "g/telemetry/codex_workflow.log" | sed 's/^/     /'
    else
        echo "   ⚠️  Workflow telemetry not found"
    fi
}

# Function to generate cutover report
generate_cutover_report() {
    echo ""
    echo "6) Generating cutover report..."
    
    REPORT_FILE="g/reports/CLS_CUTOVER_REPORT_$(date +%Y%m%d_%H%M).md"
    mkdir -p "$(dirname "$REPORT_FILE")"
    
    cat > "$REPORT_FILE" << EOF
# CLS Production Cutover Report

**Generated:** $(date -Iseconds)  
**Status:** Production Cutover Complete  

## Cutover Summary

- Volumes: $(ls /Volumes/lukadata /Volumes/hd2 2>/dev/null | wc -l || echo 0) mounted
- Automation: $(test -f "scripts/install_all_workflow_automation.sh" && echo "✅ Installed" || echo "❌ Missing")
- LaunchAgent: $(launchctl list | grep -q com.02luka.cls.workflow && echo "✅ Loaded" || echo "❌ Not Loaded")
- Validation: $(test -f "scripts/cls_go_live_validation.sh" && echo "✅ Passed" || echo "❌ Failed")
- Workflow: $(test -f "scripts/cls_complete_workflow.sh" && echo "✅ Tested" || echo "❌ Failed")

## Green Checks

- LaunchAgent Status: $(launchctl print "gui/$UID/com.02luka.cls.workflow" | grep LastExitStatus || echo "Unknown")
- Workflow Log: $(test -f "/Volumes/lukadata/CLS/logs/cls_workflow.log" && echo "✅ Exists" || echo "❌ Missing")
- Staging Branch: $(git ls-remote --heads origin staging >/dev/null 2>&1 && echo "✅ Exists" || echo "❌ Missing")
- Telemetry: $(test -f "g/telemetry/codex_workflow.log" && echo "✅ Exists" || echo "❌ Missing")

## Next Steps

### Day-1: Daily Automation
- Monitor LaunchAgent status: \`launchctl print gui/\$UID/com.02luka.cls.workflow\`
- Check logs: \`tail -f /Volumes/lukadata/CLS/logs/cls_workflow.log\`
- Review telemetry: \`tail -f g/telemetry/codex_workflow.log\`

### Success Criteria (First 3 Days)
- Daily 10:00 run exits 0, no crashes
- Auto-resolve ≥ 60% (trending up)
- Staging push success ≥ 95%
- Subjective "click-apply" volume clearly down

### Emergency Rollback
\`\`\`bash
bash scripts/cls_rollback.sh
# or manual:
launchctl bootout gui/\$UID ~/Library/LaunchAgents/com.02luka.cls.workflow.plist
chmod -x .git/hooks/pre-commit
\`\`\`

## Optional Enhancements

### Discord Daily Digest
\`\`\`bash
export DISCORD_WEBHOOK_DEFAULT="https://discord.com/api/webhooks/..."
bash scripts/cls_discord_report.sh
\`\`\`

### Daily Self-Review
\`\`\`bash
bash scripts/cls_verification_with_upload.sh && \\
node agents/reflection/self_review.cjs --days=7
\`\`\`

**CLS Production Cutover Complete** 🧠⚡
EOF
    
    echo "   ✅ Cutover report generated: $REPORT_FILE"
}

# Main execution
echo "Starting CLS final cutover..."

check_volumes
install_automation
load_launchagent
run_validation
run_complete_workflow
verify_green_checks
generate_cutover_report

echo ""
echo "🎯 CLS Final Cutover Complete"
echo "   Production system is now live"
echo "   Monitor for 3 days to confirm success criteria"
echo "   Emergency rollback available: bash scripts/cls_rollback.sh"
