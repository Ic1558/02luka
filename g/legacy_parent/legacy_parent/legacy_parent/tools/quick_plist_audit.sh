#!/usr/bin/env bash
# Quick LaunchAgent Path Audit
# Fast check for broken paths in 02luka plists

echo "=== LaunchAgent Path Audit ==="
echo ""

broken_count=0
total_count=0

for plist in ~/Library/LaunchAgents/com.02luka.*.plist; do
    [[ ! -f "$plist" ]] && continue
    ((total_count++))

    label=$(basename "$plist" .plist)
    script=$(plutil -extract ProgramArguments.0 raw "$plist" 2>/dev/null || echo "")

    # Check if path exists (skip system binaries)
    if [[ "$script" =~ ^/Users/ ]] && [[ ! -e "$script" ]]; then
        echo "❌ $label"
        echo "   Missing: $script"
        ((broken_count++))
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Total: $total_count | Broken: $broken_count"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
