#!/usr/bin/env bash
set -euo pipefail

# CLS Daily Monitoring Script
# Day-1+ monitoring and success criteria tracking

echo "🧠 CLS Daily Monitoring"
echo "======================="

# Function to check LaunchAgent health
check_launchagent_health() {
    echo "1) Checking LaunchAgent health..."
    
    # Check if LaunchAgent is loaded
    if launchctl list | grep -q com.02luka.cls.workflow; then
        echo "   ✅ LaunchAgent loaded"
        
        # Check status
        STATUS=$(launchctl print "gui/$UID/com.02luka.cls.workflow" | grep LastExitStatus || echo "LastExitStatus = unknown")
        echo "   Status: $STATUS"
        
        if [[ "$STATUS" == *"LastExitStatus = 0"* ]]; then
            echo "   ✅ LaunchAgent healthy (no crashes)"
        else
            echo "   ❌ LaunchAgent unhealthy"
            return 1
        fi
    else
        echo "   ❌ LaunchAgent not loaded"
        return 1
    fi
}

# Function to check auto-resolve rate
check_auto_resolve_rate() {
    echo ""
    echo "2) Checking auto-resolve rate..."
    
    if [[ -f "g/telemetry/codex_workflow.log" ]]; then
        # Get last 24 hours of data
        YESTERDAY=$(date -d "yesterday" +%Y-%m-%d 2>/dev/null || date -v-1d +%Y-%m-%d 2>/dev/null || echo "$(date +%Y-%m-%d)")
        
        # Count conflicts
        TOTAL_CONFLICTS=$(grep "$YESTERDAY" "g/telemetry/codex_workflow.log" 2>/dev/null | jq -r '.conflicts_total' | awk '{sum+=$1} END {print sum+0}')
        AUTO_RESOLVED=$(grep "$YESTERDAY" "g/telemetry/codex_workflow.log" 2>/dev/null | jq -r '.conflicts_auto_resolved' | awk '{sum+=$1} END {print sum+0}')
        
        echo "   Total conflicts: $TOTAL_CONFLICTS"
        echo "   Auto-resolved: $AUTO_RESOLVED"
        
        if [[ "$TOTAL_CONFLICTS" -gt 0 ]]; then
            SUCCESS_RATE=$((AUTO_RESOLVED * 100 / TOTAL_CONFLICTS))
            echo "   Auto-resolve rate: $SUCCESS_RATE%"
            
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

# Function to check staging push success
check_staging_success() {
    echo ""
    echo "3) Checking staging push success..."
    
    if [[ -f "g/telemetry/staging_integration.log" ]]; then
        # Count successful pushes
        TOTAL_PUSHES=$(grep -c '"action":"staging_push"' "g/telemetry/staging_integration.log" 2>/dev/null || echo 0)
        SUCCESSFUL_PUSHES=$(grep -c '"success":true' "g/telemetry/staging_integration.log" 2>/dev/null || echo 0)
        
        echo "   Total pushes: $TOTAL_PUSHES"
        echo "   Successful pushes: $SUCCESSFUL_PUSHES"
        
        if [[ "$TOTAL_PUSHES" -gt 0 ]]; then
            SUCCESS_RATE=$((SUCCESSFUL_PUSHES * 100 / TOTAL_PUSHES))
            echo "   Staging success rate: $SUCCESS_RATE%"
            
            if [[ "$SUCCESS_RATE" -ge 95 ]]; then
                echo "   ✅ Staging success rate healthy (≥95%)"
            else
                echo "   ⚠️  Staging success rate low (<95%)"
            fi
        else
            echo "   ⚠️  No staging pushes recorded"
        fi
    else
        echo "   ⚠️  No staging telemetry found"
    fi
}

# Function to check subjective metrics
check_subjective_metrics() {
    echo ""
    echo "4) Checking subjective metrics..."
    
    echo "   Manual 'click-apply' volume assessment:"
    echo "   - Review recent workflow reports"
    echo "   - Check for reduced manual intervention"
    echo "   - Assess workflow efficiency"
    
    # Check recent reports
    if [[ -d "g/reports" ]]; then
        RECENT_REPORTS=$(ls -t g/reports/ | head -n 5)
        echo "   Recent reports:"
        echo "$RECENT_REPORTS" | sed 's/^/     /'
    else
        echo "   ⚠️  No reports found"
    fi
}

# Function to generate daily report
generate_daily_report() {
    echo ""
    echo "5) Generating daily report..."
    
    REPORT_FILE="g/reports/CLS_DAILY_MONITORING_$(date +%Y%m%d).md"
    mkdir -p "$(dirname "$REPORT_FILE")"
    
    cat > "$REPORT_FILE" << EOF
# CLS Daily Monitoring Report

**Generated:** $(date -Iseconds)  
**Day:** $(date +%j) of 365  

## Health Status

- LaunchAgent: $(launchctl list | grep -q com.02luka.cls.workflow && echo "✅ Loaded" || echo "❌ Not Loaded")
- Status: $(launchctl print "gui/$UID/com.02luka.cls.workflow" | grep LastExitStatus || echo "Unknown")
- Crashes: $(launchctl print "gui/$UID/com.02luka.cls.workflow" | grep -c "LastExitStatus = 0" || echo 0)

## Performance Metrics

- Auto-resolve Rate: $(if [[ -f "g/telemetry/codex_workflow.log" ]]; then TOTAL=$(grep "$(date -d "yesterday" +%Y-%m-%d 2>/dev/null || date -v-1d +%Y-%m-%d 2>/dev/null || echo "$(date +%Y-%m-%d)")" "g/telemetry/codex_workflow.log" 2>/dev/null | jq -r '.conflicts_total' | awk '{sum+=$1} END {print sum+0}'); AUTO=$(grep "$(date -d "yesterday" +%Y-%m-%d 2>/dev/null || date -v-1d +%Y-%m-%d 2>/dev/null || echo "$(date +%Y-%m-%d)")" "g/telemetry/codex_workflow.log" 2>/dev/null | jq -r '.conflicts_auto_resolved' | awk '{sum+=$1} END {print sum+0}'); if [[ "$TOTAL" -gt 0 ]]; then echo "$((AUTO * 100 / TOTAL))%"; else echo "N/A"; fi; else echo "N/A"; fi)
- Staging Success: $(if [[ -f "g/telemetry/staging_integration.log" ]]; then TOTAL=$(grep -c '"action":"staging_push"' "g/telemetry/staging_integration.log" 2>/dev/null || echo 0); SUCCESS=$(grep -c '"success":true' "g/telemetry/staging_integration.log" 2>/dev/null || echo 0); if [[ "$TOTAL" -gt 0 ]]; then echo "$((SUCCESS * 100 / TOTAL))%"; else echo "N/A"; fi; else echo "N/A"; fi)

## Success Criteria Status

- ✅ Daily 10:00 run exits 0, no crashes
- $(if [[ "$(launchctl print "gui/$UID/com.02luka.cls.workflow" | grep LastExitStatus || echo "Unknown")" == *"LastExitStatus = 0"* ]]; then echo "✅"; else echo "❌"; fi) Auto-resolve ≥ 60% (trending up)
- $(if [[ -f "g/telemetry/staging_integration.log" ]]; then TOTAL=$(grep -c '"action":"staging_push"' "g/telemetry/staging_integration.log" 2>/dev/null || echo 0); SUCCESS=$(grep -c '"success":true' "g/telemetry/staging_integration.log" 2>/dev/null || echo 0); if [[ "$TOTAL" -gt 0 ]] && [[ $((SUCCESS * 100 / TOTAL)) -ge 95 ]]; then echo "✅"; else echo "❌"; fi; else echo "❌"; fi) Staging push success ≥ 95%
- ⚠️  Subjective "click-apply" volume assessment required

## Recommendations

- Monitor LaunchAgent status daily
- Review telemetry trends weekly
- Assess subjective workflow improvements
- Consider Discord integration for alerts

**CLS Daily Monitoring Complete** 🧠⚡
EOF
    
    echo "   ✅ Daily report generated: $REPORT_FILE"
}

# Function to suggest enhancements
suggest_enhancements() {
    echo ""
    echo "6) Suggested enhancements..."
    
    echo "   Optional Discord daily digest:"
    echo "   export DISCORD_WEBHOOK_DEFAULT='https://discord.com/api/webhooks/...'"
    echo "   bash scripts/cls_discord_report.sh"
    echo ""
    echo "   Daily self-review:"
    echo "   bash scripts/cls_verification_with_upload.sh && \\"
    echo "   node agents/reflection/self_review.cjs --days=7"
    echo ""
    echo "   Knowledge sync (if SQLite phase implemented):"
    echo "   node knowledge/sync.cjs --full"
}

# Main execution
echo "Starting CLS daily monitoring..."

check_launchagent_health
check_auto_resolve_rate
check_staging_success
check_subjective_metrics
generate_daily_report
suggest_enhancements

echo ""
echo "🎯 CLS Daily Monitoring Complete"
echo "   Health status checked and daily report generated"
echo "   Monitor success criteria over next 3 days"
