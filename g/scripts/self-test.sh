#!/usr/bin/env bash
set -euo pipefail
cd "$HOME/02luka"
echo "Phase5 self-test:"
test -x run/ops_verify_loop.zsh && echo "✅ verify loop script" || echo "❌ verify loop missing"
test -x run/dashboard_export.zsh && echo "✅ dashboard export" || echo "❌ dashboard export missing"
test -x run/autoheal_loop.zsh && echo "✅ auto-heal loop" || echo "❌ auto-heal loop missing"
plutil -lint LaunchAgents/com.02luka.ops.verify.loop.plist >/dev/null 2>&1 && echo "✅ verify plist" || echo "❌ verify plist"
plutil -lint LaunchAgents/com.02luka.dashboard.export.daily.plist >/dev/null 2>&1 && echo "✅ dashboard plist" || echo "❌ dashboard plist"
plutil -lint LaunchAgents/com.02luka.autoheal.loop.plist >/dev/null 2>&1 && echo "✅ autoheal plist" || echo "❌ autoheal plist"
