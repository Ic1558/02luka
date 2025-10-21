#!/usr/bin/env bash
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "Requesting sudo…"
  exec sudo -E bash "$0" "$@"
fi

echo "==> Rolling back headless settings"
# Restore more typical sleep settings (tweak to taste)
pmset -a sleep 10 displaysleep 10 disksleep 10

# Re-enable App Nap (for console user)
CONSOLE_USER="$(stat -f%Su /dev/console)"
if [ -n "$CONSOLE_USER" ]; then
  su - "$CONSOLE_USER" -c 'defaults write -g NSAppSleepDisabled -bool NO' || true
fi

# Remove keepawake daemon
launchctl bootout system/com.02luka.keepawake >/dev/null 2>&1 || true
rm -f /Library/LaunchDaemons/com.02luka.keepawake.plist
echo "==> Rolled back. You may want to reboot."
