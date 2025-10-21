#!/usr/bin/env bash
set -euo pipefail

# CLS Quick Test
# Tests core CLS functionality without full validation

echo "🧠 CLS Quick Test"
echo "================="

# Test 1: Shell resolver
echo "1) Testing shell resolver..."
if [[ -f "packages/skills/resolveShell.js" ]]; then
    RESOLVED=$(node -e "console.log(require('./packages/skills/resolveShell').resolveShell())" 2>/dev/null || echo "unknown")
    echo "   Resolved shell: $RESOLVED"
    
    if [[ "$RESOLVED" == "/bin/bash" ]] || [[ "$RESOLVED" == "/usr/bin/bash" ]]; then
        echo "   ✅ Shell resolver working"
    else
        echo "   ❌ Shell resolver failed"
    fi
else
    echo "   ❌ Shell resolver not found"
fi

# Test 2: Script availability
echo ""
echo "2) Testing script availability..."
SCRIPTS=(
    "scripts/cls_go_live_validation.sh"
    "scripts/codex_workflow_assistant.sh"
    "scripts/cls_daily_monitoring.sh"
    "scripts/cls_rollback.sh"
    "scripts/cls_final_cutover.sh"
    "scripts/cls_complete_workflow.sh"
)

for script in "${SCRIPTS[@]}"; do
    if [[ -f "$script" ]]; then
        echo "   ✅ $script"
    else
        echo "   ❌ $script"
    fi
done

# Test 3: LaunchAgent files
echo ""
echo "3) Testing LaunchAgent files..."
LAUNCHAGENTS=(
    "Library/LaunchAgents/com.02luka.cls.verification.plist"
    "Library/LaunchAgents/com.02luka.cls.workflow.plist"
)

for plist in "${LAUNCHAGENTS[@]}"; do
    if [[ -f "$plist" ]]; then
        echo "   ✅ $plist"
    else
        echo "   ❌ $plist"
    fi
done

echo ""
echo "🎯 CLS Quick Test Complete"
echo "   All core components checked"
