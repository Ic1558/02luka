#!/usr/bin/env zsh
set -euo pipefail

echo "🧹 Cleaning 02luka ghost LaunchAgents + duplicate auto.commit ..."

# 1) Bootout ghost services (ignore errors)
ghost_services=(
  com.02luka.build-latest-status
  com.02luka.clc.local
  com.02luka.followup_tracker
  com.02luka.guard-health.daily
  com.02luka.json_wo_processor
  com.02luka.mcp.health
  com.02luka.notify.worker
  com.02luka.sync.gdrive.4h
  com.02luka.wo_executor
)

for service in "${ghost_services[@]}"; do
  echo "  - bootout $service"
  launchctl bootout "gui/$(id -u)/$service" 2>/dev/null || true
done

# 2) Remove duplicate old auto.commit plist (new one is auto-commit)
old_plist="$HOME/Library/LaunchAgents/com.02luka.auto.commit.plist"
if [[ -f "$old_plist" ]]; then
  echo "  - removing old plist: $old_plist"
  rm "$old_plist"
else
  echo "  - old auto.commit plist not found (already removed?)"
fi

echo "✅ Cleanup script finished."
echo "👉 Suggested checks:"
echo "   launchctl list | grep 'com.02luka' | awk '\$2 == \"127\"' | wc -l"
echo "   ls ~/Library/LaunchAgents/com.02luka.auto.commit.plist || echo 'no old plist'"
