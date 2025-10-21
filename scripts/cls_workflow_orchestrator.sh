#!/usr/bin/env bash
set -euo pipefail

# CLS Workflow Orchestrator
# Coordinates all workflow automation components

echo "🧠 CLS Workflow Orchestrator"
echo "============================"

# Function to check system status
check_system_status() {
    echo "1) Checking system status..."
    
    # Check LaunchAgents
    echo "   LaunchAgents:"
    launchctl list | grep com.02luka.cls || echo "     (No CLS LaunchAgents loaded)"
    
    # Check git status
    echo "   Git status:"
    if git rev-parse --git-dir >/dev/null 2>&1; then
        echo "     Repository: $(git rev-parse --show-toplevel)"
        echo "     Branch: $(git branch --show-current)"
        echo "     Status: $(git status --porcelain | wc -l) files changed"
    else
        echo "     (Not in a git repository)"
    fi
    
    # Check telemetry
    echo "   Telemetry:"
    if [[ -d "g/telemetry" ]]; then
        echo "     Files: $(ls g/telemetry/ | wc -l)"
        echo "     Latest: $(ls -t g/telemetry/ | head -n1)"
    else
        echo "     (No telemetry found)"
    fi
}

# Function to run workflow scan
run_workflow_scan() {
    echo ""
    echo "2) Running workflow scan..."
    
    if [[ -f "scripts/codex_workflow_assistant.sh" ]]; then
        bash scripts/codex_workflow_assistant.sh --scan
        echo "✅ Workflow scan completed"
    else
        echo "❌ Workflow assistant not found"
        return 1
    fi
}

# Function to resolve conflicts
resolve_conflicts() {
    echo ""
    echo "3) Resolving conflicts..."
    
    if [[ -f "scripts/auto_resolve_conflicts.sh" ]]; then
        bash scripts/auto_resolve_conflicts.sh
        echo "✅ Conflict resolution completed"
    else
        echo "❌ Auto-resolve script not found"
        return 1
    fi
}

# Function to apply changes
apply_changes() {
    echo ""
    echo "4) Applying changes..."
    
    if [[ -f "scripts/codex_batch_apply_with_staging.sh" ]]; then
        bash scripts/codex_batch_apply_with_staging.sh
        echo "✅ Changes applied and pushed to staging"
    else
        echo "❌ Batch apply script not found"
        return 1
    fi
}

# Function to run verification
run_verification() {
    echo ""
    echo "5) Running verification..."
    
    if [[ -f "scripts/cls_go_live_final.sh" ]]; then
        bash scripts/cls_go_live_final.sh
        echo "✅ Verification completed"
    else
        echo "❌ Verification script not found"
        return 1
    fi
}

# Function to generate report
generate_report() {
    echo ""
    echo "6) Generating report..."
    
    REPORT_FILE="g/reports/cls_workflow_orchestrator_$(date +%Y%m%d_%H%M).md"
    mkdir -p "$(dirname "$REPORT_FILE")"
    
    cat > "$REPORT_FILE" << EOF
# CLS Workflow Orchestrator Report

**Generated:** $(date -Iseconds)  
**Status:** Complete

## System Status

- LaunchAgents: $(launchctl list | grep -c com.02luka.cls || echo 0)
- Git Repository: $(git rev-parse --show-toplevel 2>/dev/null || echo "Not found")
- Telemetry Files: $(ls g/telemetry/ 2>/dev/null | wc -l || echo 0)

## Workflow Execution

- Workflow Scan: ✅ Completed
- Conflict Resolution: ✅ Completed
- Change Application: ✅ Completed
- Verification: ✅ Completed

## Next Steps

- Monitor telemetry: bash scripts/cls_telemetry_dashboard.sh
- Run complete workflow: bash scripts/cls_complete_workflow.sh
- Check LaunchAgent status: launchctl list | grep com.02luka.cls

EOF
    
    echo "✅ Report generated: $REPORT_FILE"
}

# Function to log telemetry
log_telemetry() {
    echo ""
    echo "7) Logging telemetry..."
    
    TELEM_FILE="g/telemetry/cls_workflow_orchestrator.log"
    mkdir -p "$(dirname "$TELEM_FILE")"
    
    cat >> "$TELEM_FILE" << EOF
{"timestamp":"$(date -Iseconds)","action":"orchestrator_run","status":"complete","launchagents":$(launchctl list | grep -c com.02luka.cls || echo 0),"telemetry_files":$(ls g/telemetry/ 2>/dev/null | wc -l || echo 0)}
EOF
    
    echo "✅ Telemetry logged to $TELEM_FILE"
}

# Main execution
echo "Starting CLS Workflow Orchestrator..."

check_system_status
run_workflow_scan
resolve_conflicts
apply_changes
run_verification
generate_report
log_telemetry

echo ""
echo "🎯 CLS Workflow Orchestrator Complete"
echo "   All workflow automation components executed successfully"
echo "   Report generated and telemetry logged"
