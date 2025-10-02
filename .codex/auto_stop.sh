#!/usr/bin/env bash
# Auto-stop Hybrid Memory System
# This script runs automatically when Cursor closes

set -euo pipefail

echo "🛑 Auto-stopping Hybrid Memory System"
echo "======================================"

# Check if session is active
if [ ! -f ".codex/session_active.lock" ]; then
    echo "⚠️  No active session found"
    exit 0
fi

# Save context
echo "💾 Saving context..."
bash .codex/save_context.sh

# Remove session lock
rm -f .codex/session_active.lock

echo "✅ Hybrid Memory System stopped"
echo "✅ Context saved for next session"
