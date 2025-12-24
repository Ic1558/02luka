#!/usr/bin/env zsh
# tools/test_guard_breakage.zsh

# 1. Test JSON Breakage with quotes
echo "Testing JSON breakage..."
CMD='echo "hello" \ world'
echo "$CMD" | zsh tools/guard_runtime.zsh --cmd - 2>/dev/null

# Check the last line of telemetry
LAST_LINE=$(tail -n 1 g/telemetry/runtime_guard.jsonl)
echo "Last Telemetry Line: $LAST_LINE"

# Verify validity using python
echo "$LAST_LINE" | python3 -c "import sys, json; print(json.load(sys.stdin))" 2>&1
if [[ $? -ne 0 ]]; then
    echo "❌ JSON is INVALID (Confirmed Codex Finding #1)"
else
    echo "✅ JSON is VALID"
fi
