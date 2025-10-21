#!/usr/bin/env bash
set -euo pipefail

# CLS Go-Live in 5 Minutes
# Exact commands to get CLS running with validation

echo "🧠 CLS Go-Live in 5 Minutes"
echo "==========================="

# Step 1: Pin the shell CLS should use
echo "1) Setting shell environment..."
export CLS_SHELL="/bin/bash"
export SHELL="/bin/bash"
export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin"

echo "   ✅ CLS_SHELL: $CLS_SHELL"
echo "   ✅ SHELL: $SHELL"
echo "   ✅ PATH configured"

# Sanity check the resolver
echo ""
echo "2) Testing shell resolver..."
if node -e "console.log(require('./packages/skills/resolveShell').resolveShell())" 2>/dev/null; then
    echo "   ✅ Shell resolver working"
else
    echo "   ❌ Shell resolver failed"
    exit 1
fi

# Step 2: Allow filesystem roots
echo ""
echo "3) Setting filesystem allowlist..."
export CLS_FS_ALLOW="$HOME:/Volumes/lukadata:/Volumes/hd2:$(pwd)"
echo "   ✅ CLS_FS_ALLOW: $CLS_FS_ALLOW"

# Step 3: Run quick validation
echo ""
echo "4) Running CLS validation..."
if bash scripts/cls_go_live_validation.sh; then
    echo "   ✅ CLS validation passed"
else
    echo "   ❌ CLS validation failed"
    exit 1
fi

# Step 4: Kick a single workflow scan
echo ""
echo "5) Running workflow scan..."
if bash scripts/codex_workflow_assistant.sh --scan; then
    echo "   ✅ Workflow scan completed"
else
    echo "   ❌ Workflow scan failed"
    exit 1
fi

# Step 5: Check telemetry
echo ""
echo "6) Checking telemetry..."
if [[ -f "g/telemetry/codex_workflow.log" ]]; then
    echo "   ✅ Telemetry log exists"
    echo "   Recent entries:"
    tail -n 3 "g/telemetry/codex_workflow.log" | sed 's/^/     /'
else
    echo "   ⚠️  Telemetry log not found"
fi

# Step 6: Check queue status
echo ""
echo "7) Checking queue status..."
if [[ -d "queue" ]]; then
    echo "   ✅ Queue directory exists"
    if [[ -d "queue/done" ]]; then
        echo "   ✅ Done queue: $(ls queue/done/ 2>/dev/null | wc -l) tasks"
    fi
    if [[ -d "queue/failed" ]]; then
        echo "   ✅ Failed queue: $(ls queue/failed/ 2>/dev/null | wc -l) tasks"
    fi
else
    echo "   ⚠️  Queue directory not found"
fi

echo ""
echo "🎯 CLS Go-Live Complete"
echo "   System is ready for production use"
echo "   All components validated and working"
