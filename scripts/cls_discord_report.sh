#!/usr/bin/env bash
set -euo pipefail

# CLS Discord Daily Report
# Posts daily conflict digest to Discord webhook

echo "🧠 CLS Discord Daily Report"
echo "==========================="

# Check for Discord webhook
if [[ -z "${DISCORD_WEBHOOK_DEFAULT:-}" ]]; then
    echo "❌ DISCORD_WEBHOOK_DEFAULT not set"
    echo "   Set your Discord webhook URL:"
    echo "   export DISCORD_WEBHOOK_DEFAULT='https://discord.com/api/webhooks/...'"
    exit 1
fi

# Function to get conflict metrics
get_conflict_metrics() {
    echo "1) Gathering conflict metrics..."
    
    if [[ ! -f "g/telemetry/codex_workflow.log" ]]; then
        echo "   ⚠️  No telemetry data found"
        return 1
    fi
    
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
    else
        SUCCESS_RATE=100
        echo "   Auto-resolve rate: 100% (no conflicts)"
    fi
}

# Function to get LaunchAgent status
get_launchagent_status() {
    echo ""
    echo "2) Checking LaunchAgent status..."
    
    if launchctl list | grep -q com.02luka.cls.workflow; then
        STATUS=$(launchctl print "gui/$UID/com.02luka.cls.workflow" | grep LastExitStatus || echo "LastExitStatus = unknown")
        echo "   LaunchAgent: $STATUS"
        
        if [[ "$STATUS" == *"LastExitStatus = 0"* ]]; then
            LAUNCHAGENT_STATUS="✅ Healthy"
        else
            LAUNCHAGENT_STATUS="⚠️  Issues detected"
        fi
    else
        LAUNCHAGENT_STATUS="❌ Not loaded"
    fi
}

# Function to get staging status
get_staging_status() {
    echo ""
    echo "3) Checking staging status..."
    
    if git ls-remote --heads origin staging >/dev/null 2>&1; then
        STAGING_COMMITS=$(git log origin/staging --since="yesterday" --oneline | wc -l)
        echo "   Staging commits yesterday: $STAGING_COMMITS"
        
        if [[ "$STAGING_COMMITS" -gt 0 ]]; then
            STAGING_STATUS="✅ Active ($STAGING_COMMITS commits)"
        else
            STAGING_STATUS="⚠️  No activity"
        fi
    else
        STAGING_STATUS="❌ No remote staging"
    fi
}

# Function to generate Discord message
generate_discord_message() {
    echo ""
    echo "4) Generating Discord message..."
    
    # Determine status emoji
    if [[ "$SUCCESS_RATE" -ge 80 ]]; then
        STATUS_EMOJI="🟢"
    elif [[ "$SUCCESS_RATE" -ge 60 ]]; then
        STATUS_EMOJI="🟡"
    else
        STATUS_EMOJI="🔴"
    fi
    
    # Create Discord message
    cat > /tmp/cls_discord_message.json << EOF
{
  "content": "🧠 **CLS Daily Report** - $(date +%Y-%m-%d)",
  "embeds": [
    {
      "title": "Workflow Automation Status",
      "color": $(if [[ "$SUCCESS_RATE" -ge 80 ]]; then echo "65280"; elif [[ "$SUCCESS_RATE" -ge 60 ]]; then echo "16776960"; else echo "16711680"; fi),
      "fields": [
        {
          "name": "Conflict Resolution",
          "value": "**Rate:** $SUCCESS_RATE%\\n**Total:** $TOTAL_CONFLICTS\\n**Auto-resolved:** $AUTO_RESOLVED",
          "inline": true
        },
        {
          "name": "LaunchAgent",
          "value": "$LAUNCHAGENT_STATUS",
          "inline": true
        },
        {
          "name": "Staging",
          "value": "$STAGING_STATUS",
          "inline": true
        }
      ],
      "footer": {
        "text": "CLS Workflow Automation • $(date +%H:%M)"
      }
    }
  ]
}
EOF
    
    echo "   ✅ Discord message generated"
}

# Function to send to Discord
send_to_discord() {
    echo ""
    echo "5) Sending to Discord..."
    
    if curl -s -X POST "$DISCORD_WEBHOOK_DEFAULT" \
        -H 'Content-Type: application/json' \
        -d @/tmp/cls_discord_message.json; then
        echo "   ✅ Message sent to Discord"
    else
        echo "   ❌ Failed to send to Discord"
        return 1
    fi
}

# Function to clean up
cleanup() {
    echo ""
    echo "6) Cleaning up..."
    
    rm -f /tmp/cls_discord_message.json
    echo "   ✅ Temporary files cleaned up"
}

# Main execution
echo "Starting CLS Discord daily report..."

get_conflict_metrics
get_launchagent_status
get_staging_status
generate_discord_message
send_to_discord
cleanup

echo ""
echo "🎯 CLS Discord Daily Report Complete"
echo "   Daily conflict digest posted to Discord"
echo "   Status: $STATUS_EMOJI $SUCCESS_RATE% auto-resolve rate"
