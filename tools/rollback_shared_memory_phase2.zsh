#!/usr/bin/env zsh
set -euo pipefail

echo "Rolling back Shared Memory Phase 2 components..."

# Unload LaunchAgent
launchctl unload ~/Library/LaunchAgents/com.02luka.memory.metrics.plist >/dev/null 2>&1 || true

# Remove LaunchAgent plist
rm -f ~/Library/LaunchAgents/com.02luka.memory.metrics.plist

# Remove scripts
rm -f ~/02luka/tools/gc_memory_sync.sh
rm -f ~/02luka/tools/memory_metrics.zsh
rm -f ~/02luka/tools/shared_memory_health.zsh

# Remove CLS bridge
rm -rf ~/02luka/agents/cls_bridge

# Preserve data
echo "ℹ️  Preserved for audit:"
echo "   - ~/02luka/metrics/"

echo "✅ Rolled back Shared Memory Phase 2 components."
