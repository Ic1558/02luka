#!/usr/bin/env bash
set -euo pipefail

# CLS Activation Script
# Sources shell configuration and activates CLS environment

echo "🧠 CLS Activation"
echo "================="

# Set environment variables directly
export CLS_SHELL="/bin/bash"
export SHELL="/bin/bash"
export PATH="/usr/local/bin:/usr/bin:/bin"

echo "✅ CLS shell environment activated"
echo "   CLS_SHELL: $CLS_SHELL"
echo "   SHELL: $SHELL"

# Test shell resolver
if [[ -f "packages/skills/resolveShell.js" ]]; then
    echo "   Testing shell resolver..."
    RESOLVED=$(node -e "console.log(require('./packages/skills/resolveShell').resolveShell())" 2>/dev/null || echo "unknown")
    echo "   Resolved shell: $RESOLVED"
    
    if [[ "$RESOLVED" == "/bin/bash" ]] || [[ "$RESOLVED" == "/usr/bin/bash" ]]; then
        echo "   ✅ Shell resolver working correctly"
    else
        echo "   ⚠️  Shell resolver returned unexpected value"
    fi
else
    echo "   ⚠️  Shell resolver not found"
fi

echo ""
echo "🎯 CLS Environment Activated"
echo "   Available commands:"
echo "   - cls-validate: Run CLS validation"
echo "   - cls-scan: Run workflow scan"
echo "   - cls-monitor: Run daily monitoring"
echo "   - cls-rollback: Emergency rollback"
echo "   - cls-cutover: Production cutover"
echo "   - cls-workflow: Complete workflow"
