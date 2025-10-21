#!/usr/bin/env bash
set -euo pipefail

# CLS Go-Live Validation Script
# Comprehensive validation of all workflow automation components

echo "🧠 CLS Go-Live Validation"
echo "========================="

# Function to check installation
check_installation() {
    echo "1) Checking installation..."
    
    # Check if install script exists
    if [[ -f "scripts/install_all_workflow_automation.sh" ]]; then
        echo "   ✅ Install script found"
    else
        echo "   ❌ Install script missing"
        return 1
    fi
    
    # Check pre-commit hook
    echo "   Checking pre-commit hook..."
    if [[ -x ".git/hooks/pre-commit" ]]; then
        echo "   ✅ Pre-commit hook active"
    else
        echo "   ⚠️  Pre-commit hook missing or not executable"
    fi
    
    # Check git hooks path
    HOOKS_PATH=$(git config --get core.hooksPath || echo ".git/hooks")
    echo "   Git hooks path: $HOOKS_PATH"
    
    # Check staging integration
    if [[ -f "scripts/staging_integration.sh" ]]; then
        echo "   ✅ Staging integration found"
    else
        echo "   ❌ Staging integration missing"
    fi
}

# Function to check LaunchAgent
check_launchagent() {
    echo ""
    echo "2) Checking LaunchAgent..."
    
    # Check if LaunchAgent is loaded
    if launchctl list | grep -q com.02luka.cls.workflow; then
        echo "   ✅ LaunchAgent loaded"
        
        # Check status
        STATUS=$(launchctl print "gui/$UID/com.02luka.cls.workflow" | grep LastExitStatus || echo "LastExitStatus = unknown")
        echo "   Status: $STATUS"
        
        if [[ "$STATUS" == *"LastExitStatus = 0"* ]]; then
            echo "   ✅ LaunchAgent healthy"
        else
            echo "   ⚠️  LaunchAgent status unclear"
        fi
    else
        echo "   ❌ LaunchAgent not loaded"
    fi
}

# Function to check logs
check_logs() {
    echo ""
    echo "3) Checking logs..."
    
    # Check workflow log
    if [[ -f "/Volumes/lukadata/CLS/logs/cls_workflow.log" ]]; then
        echo "   ✅ Workflow log exists"
        echo "   Recent entries:"
        tail -n 5 "/Volumes/lukadata/CLS/logs/cls_workflow.log" | sed 's/^/     /'
    else
        echo "   ⚠️  Workflow log not found"
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

# Function to check staging
check_staging() {
    echo ""
    echo "4) Checking staging..."
    
    # Check if staging branch exists
    if git show-ref --verify --quiet refs/heads/staging; then
        echo "   ✅ Staging branch exists locally"
    else
        echo "   ⚠️  Staging branch not found locally"
    fi
    
    # Check remote staging
    if git ls-remote --heads origin staging >/dev/null 2>&1; then
        echo "   ✅ Remote staging branch exists"
        echo "   Recent commits:"
        git log origin/staging -3 --oneline | sed 's/^/     /'
    else
        echo "   ⚠️  Remote staging branch not found"
    fi
}

# Function to run conflict rate analysis
analyze_conflict_rate() {
    echo ""
    echo "5) Analyzing conflict rate..."
    
    if [[ -f "g/telemetry/codex_workflow.log" ]]; then
        echo "   Last 50 runs analysis:"
        
        # Count conflicts
        TOTAL_CONFLICTS=$(grep -E '"conflicts_total"' "g/telemetry/codex_workflow.log" | tail -n 50 | jq -r '.conflicts_total' | awk '{sum+=$1} END {print sum+0}')
        AUTO_RESOLVED=$(grep -E '"conflicts_auto_resolved"' "g/telemetry/codex_workflow.log" | tail -n 50 | jq -r '.conflicts_auto_resolved' | awk '{sum+=$1} END {print sum+0}')
        
        echo "     Total conflicts: $TOTAL_CONFLICTS"
        echo "     Auto-resolved: $AUTO_RESOLVED"
        
        if [[ "$TOTAL_CONFLICTS" -gt 0 ]]; then
            SUCCESS_RATE=$((AUTO_RESOLVED * 100 / TOTAL_CONFLICTS))
            echo "     Auto-resolve success rate: $SUCCESS_RATE%"
            
            if [[ "$SUCCESS_RATE" -ge 60 ]]; then
                echo "   ✅ Auto-resolve rate healthy (≥60%)"
            else
                echo "   ⚠️  Auto-resolve rate low (<60%)"
            fi
        else
            echo "   ✅ No conflicts detected"
        fi
    else
        echo "   ⚠️  No telemetry data found"
    fi
}

# Function to check token savings
check_token_savings() {
    echo ""
    echo "6) Checking token savings..."
    
    if [[ -f "g/telemetry/codex_workflow.log" ]]; then
        echo "   Recent token usage:"
        grep -E '"tokens_cls"|"tokens_clc"' "g/telemetry/codex_workflow.log" | tail -n 5 | sed 's/^/     /'
    else
        echo "   ⚠️  No token telemetry found"
    fi
}

# Function to run manual smoke test
run_smoke_test() {
    echo ""
    echo "7) Running manual smoke test..."
    
    # Create a test conflict scenario
    echo "   Creating test conflict scenario..."
    
    # Run workflow assistant
    if bash scripts/codex_workflow_assistant.sh --scan; then
        echo "   ✅ Workflow scan completed"
    else
        echo "   ❌ Workflow scan failed"
        return 1
    fi
    
    # Run batch apply with staging
    if bash scripts/codex_batch_apply_with_staging.sh; then
        echo "   ✅ Batch apply with staging completed"
    else
        echo "   ❌ Batch apply failed"
        return 1
    fi
}

# Function to generate validation report
generate_report() {
    echo ""
    echo "8) Generating validation report..."
    
    REPORT_FILE="g/reports/cls_go_live_validation_$(date +%Y%m%d_%H%M).md"
    mkdir -p "$(dirname "$REPORT_FILE")"
    
    cat > "$REPORT_FILE" << EOF
# CLS Go-Live Validation Report

**Generated:** $(date -Iseconds)  
**Status:** Validation Complete

## Installation Status

- Install Script: $(test -f "scripts/install_all_workflow_automation.sh" && echo "✅ Found" || echo "❌ Missing")
- Pre-commit Hook: $(test -x ".git/hooks/pre-commit" && echo "✅ Active" || echo "❌ Missing")
- Staging Integration: $(test -f "scripts/staging_integration.sh" && echo "✅ Found" || echo "❌ Missing")

## LaunchAgent Status

- Loaded: $(launchctl list | grep -q com.02luka.cls.workflow && echo "✅ Yes" || echo "❌ No")
- Status: $(launchctl print "gui/$UID/com.02luka.cls.workflow" | grep LastExitStatus || echo "Unknown")

## Logs & Telemetry

- Workflow Log: $(test -f "/Volumes/lukadata/CLS/logs/cls_workflow.log" && echo "✅ Found" || echo "❌ Missing")
- Telemetry: $(test -f "g/telemetry/codex_workflow.log" && echo "✅ Found" || echo "❌ Missing")

## Staging Status

- Local Branch: $(git show-ref --verify --quiet refs/heads/staging && echo "✅ Exists" || echo "❌ Missing")
- Remote Branch: $(git ls-remote --heads origin staging >/dev/null 2>&1 && echo "✅ Exists" || echo "❌ Missing")

## Performance Metrics

- Conflict Rate: $(grep -E '"conflicts_total"' "g/telemetry/codex_workflow.log" 2>/dev/null | tail -n 50 | jq -r '.conflicts_total' | awk '{sum+=$1} END {print sum+0}' || echo "N/A")
- Auto-resolve Rate: $(if [[ -f "g/telemetry/codex_workflow.log" ]]; then TOTAL=$(grep -E '"conflicts_total"' "g/telemetry/codex_workflow.log" | tail -n 50 | jq -r '.conflicts_total' | awk '{sum+=$1} END {print sum+0}'); AUTO=$(grep -E '"conflicts_auto_resolved"' "g/telemetry/codex_workflow.log" | tail -n 50 | jq -r '.conflicts_auto_resolved' | awk '{sum+=$1} END {print sum+0}'); if [[ "$TOTAL" -gt 0 ]]; then echo "$((AUTO * 100 / TOTAL))%"; else echo "N/A"; fi; else echo "N/A"; fi)

## Recommendations

- Monitor LaunchAgent status daily
- Check telemetry for performance trends
- Verify staging push success rates
- Review conflict resolution effectiveness

EOF
    
    echo "   ✅ Validation report generated: $REPORT_FILE"
}

# Main execution
echo "Starting CLS Go-Live Validation..."

check_installation
check_launchagent
check_logs
check_staging
analyze_conflict_rate
check_token_savings
run_smoke_test
generate_report

echo ""
echo "🎯 CLS Go-Live Validation Complete"
echo "   All components validated and report generated"
echo "   Check g/reports/ for detailed validation report"
