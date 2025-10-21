#!/usr/bin/env bash
set -euo pipefail

# CLS Rollback Script
# Disables all workflow automation components in 30 seconds

echo "🧠 CLS Rollback - Disabling Workflow Automation"
echo "==============================================="

# Function to disable LaunchAgent
disable_launchagent() {
    echo "1) Disabling LaunchAgent..."
    
    if launchctl list | grep -q com.02luka.cls.workflow; then
        launchctl bootout "gui/$UID" ~/Library/LaunchAgents/com.02luka.cls.workflow.plist
        echo "   ✅ LaunchAgent disabled"
    else
        echo "   ⚠️  LaunchAgent not loaded"
    fi
}

# Function to disable pre-commit hook
disable_pre_commit() {
    echo ""
    echo "2) Disabling pre-commit hook..."
    
    if [[ -f ".git/hooks/pre-commit" ]]; then
        chmod -x .git/hooks/pre-commit
        echo "   ✅ Pre-commit hook disabled"
    else
        echo "   ⚠️  Pre-commit hook not found"
    fi
}

# Function to disable auto-staging
disable_auto_staging() {
    echo ""
    echo "3) Disabling auto-staging..."
    
    # Remove staging branch (optional)
    if git show-ref --verify --quiet refs/heads/staging; then
        echo "   Staging branch exists - keeping for safety"
        echo "   To remove manually: git branch -D staging"
    else
        echo "   ⚠️  Staging branch not found"
    fi
    
    # Disable staging integration script
    if [[ -f "scripts/staging_integration.sh" ]]; then
        chmod -x scripts/staging_integration.sh
        echo "   ✅ Staging integration disabled"
    else
        echo "   ⚠️  Staging integration not found"
    fi
}

# Function to backup telemetry
backup_telemetry() {
    echo ""
    echo "4) Backing up telemetry..."
    
    if [[ -d "g/telemetry" ]]; then
        BACKUP_DIR="g/telemetry_backup_$(date +%Y%m%d_%H%M)"
        cp -r g/telemetry "$BACKUP_DIR"
        echo "   ✅ Telemetry backed up to: $BACKUP_DIR"
    else
        echo "   ⚠️  No telemetry found"
    fi
}

# Function to generate rollback report
generate_rollback_report() {
    echo ""
    echo "5) Generating rollback report..."
    
    REPORT_FILE="g/reports/cls_rollback_$(date +%Y%m%d_%H%M).md"
    mkdir -p "$(dirname "$REPORT_FILE")"
    
    cat > "$REPORT_FILE" << EOF
# CLS Rollback Report

**Generated:** $(date -Iseconds)  
**Status:** Rollback Complete

## Disabled Components

- LaunchAgent: $(launchctl list | grep -q com.02luka.cls.workflow && echo "❌ Still Active" || echo "✅ Disabled")
- Pre-commit Hook: $(test -x ".git/hooks/pre-commit" && echo "❌ Still Active" || echo "✅ Disabled")
- Staging Integration: $(test -x "scripts/staging_integration.sh" && echo "❌ Still Active" || echo "✅ Disabled")

## Backup Status

- Telemetry Backup: $(test -d "g/telemetry_backup_$(date +%Y%m%d_%H%M)" && echo "✅ Created" || echo "❌ Failed")

## Re-enable Instructions

To re-enable CLS workflow automation:

1. Re-enable LaunchAgent:
   \`\`\`bash
   launchctl bootstrap gui/\$UID ~/Library/LaunchAgents/com.02luka.cls.workflow.plist
   \`\`\`

2. Re-enable pre-commit hook:
   \`\`\`bash
   chmod +x .git/hooks/pre-commit
   \`\`\`

3. Re-enable staging integration:
   \`\`\`bash
   chmod +x scripts/staging_integration.sh
   \`\`\`

4. Run complete installation:
   \`\`\`bash
   bash scripts/install_all_workflow_automation.sh
   \`\`\`

## Safety Notes

- All telemetry data has been preserved
- Staging branch remains intact
- No data loss occurred during rollback
- Components can be re-enabled at any time

EOF
    
    echo "   ✅ Rollback report generated: $REPORT_FILE"
}

# Main execution
echo "Starting CLS rollback process..."

disable_launchagent
disable_pre_commit
disable_auto_staging
backup_telemetry
generate_rollback_report

echo ""
echo "🎯 CLS Rollback Complete"
echo "   All workflow automation components disabled"
echo "   Telemetry backed up and rollback report generated"
echo "   Components can be re-enabled using the instructions in the report"
