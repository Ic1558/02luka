#!/usr/bin/env zsh
set -euo pipefail

echo "Rolling back Shared Memory Phase 4 components..."

# Unload LaunchAgent
launchctl unload ~/Library/LaunchAgents/com.02luka.memory.hub.plist >/dev/null 2>&1 || true

# Remove LaunchAgent plist
rm -f ~/Library/LaunchAgents/com.02luka.memory.hub.plist

# Remove scripts
rm -f ~/02luka/tools/mary_memory_hook.zsh
rm -f ~/02luka/tools/rnd_memory_hook.zsh

# Remove memory hub
rm -r -f ~/02luka/agents/memory_hub

# Revert health check (remove Phase 4 checks)
# Note: Manual revert needed for health check

# Preserve data
echo "ℹ️  Preserved for audit:"
echo "   - ~/02luka/shared_memory/"
echo "   - Redis data (memory:agents:* keys)"

echo "✅ Rolled back Shared Memory Phase 4 components."
