#!/usr/bin/env bash
# Remove 19 broken LaunchAgents that point to non-existent paths
# Date: 2025-10-03

set -euo pipefail

BROKEN_AGENTS=(
    "com.02luka.agent.dispatcher"
    "com.02luka.agent.hybrid"
    "com.02luka.backup.daily"
    "com.02luka.clc.poller"
    "com.02luka.clc.simple"
    "com.02luka.eda.alert"
    "com.02luka.entry_router"
    "com.02luka.execd"
    "com.02luka.gg_auto_dispatcher"
    "com.02luka.gg_ingest_uds"
    "com.02luka.local_orchestrator"
    "com.02luka.ping"
    "com.02luka.pipeline.lagmonitor"
    "com.02luka.reboot_guard"
    "com.02luka.sync.daemon"
    "com.02luka.system_runner.v2"
    "com.02luka.system_runner.v3"
    "com.02luka.system_runner_gateway"
    "com.02luka.vp_bridge"
)

echo "Removing ${#BROKEN_AGENTS[@]} broken LaunchAgents..."
echo ""

removed=0
for label in "${BROKEN_AGENTS[@]}"; do
    # Unload agent
    if launchctl bootout "gui/$(id -u)/$label" 2>/dev/null; then
        echo "  Unloaded: $label"
    fi

    # Remove plist
    if [ -f ~/Library/LaunchAgents/$label.plist ]; then
        if rm ~/Library/LaunchAgents/$label.plist 2>/dev/null; then
            echo "✅ Removed: $label"
            ((removed++))
        else
            echo "⚠️  Protected: $label (needs manual removal)"
        fi
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Cleanup Complete"
echo "Removed: $removed/${#BROKEN_AGENTS[@]}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
