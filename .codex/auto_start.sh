#!/usr/bin/env bash
# Auto-start Hybrid Memory System
# This script runs automatically when Cursor opens

set -euo pipefail

echo "🚀 Auto-starting Hybrid Memory System"
echo "======================================"

# Check if we're in the right directory
if [ ! -f ".codex/load_context.sh" ]; then
    echo "⚠️  Not in 02luka project directory, skipping auto-start"
    exit 0
fi

# Check if already running
if [ -f ".codex/session_active.lock" ]; then
    echo "✅ Hybrid Memory System already active"
    exit 0
fi

# Create session lock
touch .codex/session_active.lock

# Load context
echo "🧠 Loading context..."
bash .codex/load_context.sh

# Adapt style
echo "🎨 Adapting style..."
bash .codex/adapt_style.sh

# Display welcome message
echo ""
echo "🎯 Hybrid Memory System Ready!"
echo "==============================="
echo "✅ Context loaded"
echo "✅ Style adapted"
echo "✅ AI personalized for you"
echo ""
echo "💡 Tips:"
echo "   - Use 'bash .codex/save_context.sh' to save before closing"
echo "   - Use 'bash .codex/load_context.sh' to reload context"
echo "   - Use 'bash .codex/adapt_style.sh' to re-adapt style"
echo ""
echo "🚀 Ready for AI assistance!"






