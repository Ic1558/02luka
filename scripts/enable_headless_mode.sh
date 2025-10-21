#!/usr/bin/env bash
set -euo pipefail

# --- Config ---
USER_PLISTS=(
  "$HOME/Library/LaunchAgents/com.02luka.cls.verification.plist"
  "$HOME/Library/LaunchAgents/com.02luka.cls.workflow.plist"
)
KEEPALIVE_DAEMON_PLIST="/Library/LaunchDaemons/com.02luka.keepawake.plist"
KEEPALIVE_LOG="/var/log/02luka-keepawake.log"

echo "==> Headless mode: starting (macOS required)"
if ! command -v sw_vers >/dev/null 2>&1; then
  echo "This script is for macOS only." >&2; exit 1
fi

# --- Ask for sudo once up front ---
if [ "$EUID" -ne 0 ]; then
  echo "Requesting sudo…"
  exec sudo -E bash "$0" "$@"
fi

# --- 1) System sleep settings (headless-friendly) ---
echo "==> Setting pmset to disable system/display/disk sleep"
pmset -a sleep 0
pmset -a displaysleep 0
pmset -a disksleep 0
pmset -a womp 1        # Wake on network access

# --- 2) Disable App Nap globally (user domain) ---
# We need to write this for the signed-in user (not root). Use the console user if available.
CONSOLE_USER="$(stat -f%Su /dev/console)"
USER_HOME="$(dscl . -read /Users/"$CONSOLE_USER" NFSHomeDirectory 2>/dev/null | awk '{print $2}')"
if [ -n "$CONSOLE_USER" ] && [ -n "$USER_HOME" ] && [ -d "$USER_HOME" ]; then
  echo "==> Disabling App Nap for user: $CONSOLE_USER"
  su - "$CONSOLE_USER" -c 'defaults write -g NSAppSleepDisabled -bool YES'
else
  echo "WARN: Could not resolve console user; skipping NSAppSleepDisabled."
fi

# --- 3) System daemon that keeps the Mac awake even when locked/logged out ---
echo "==> Installing keep-awake LaunchDaemon: $KEEPALIVE_DAEMON_PLIST"
cat >/tmp/com.02luka.keepawake.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.02luka.keepawake</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/caffeinate</string>
    <string>-dimsu</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>/var/log/02luka-keepawake.log</string>
  <key>StandardErrorPath</key><string>/var/log/02luka-keepawake.log</string>
  <key>ProcessType</key><string>Background</string>
</dict>
</plist>
PLIST

# Move into place with correct perms
launchctl bootout system/com.02luka.keepawake >/dev/null 2>&1 || true
install -o root -g wheel -m 0644 /tmp/com.02luka.keepawake.plist "$KEEPALIVE_DAEMON_PLIST"
touch "$KEEPALIVE_LOG" && chown root:wheel "$KEEPALIVE_LOG" && chmod 0644 "$KEEPALIVE_LOG"
launchctl bootstrap system "$KEEPALIVE_DAEMON_PLIST"
launchctl kickstart -k system/com.02luka.keepawake
echo "    • keepawake daemon loaded."

# --- 4) Harden existing CLS LaunchAgents to survive lock/sleep ---
PLISTBUDDY="/usr/libexec/PlistBuddy"
for P in "${USER_PLISTS[@]}"; do
  if [ -f "$P" ]; then
    echo "==> Hardening $P"
    # Ensure keys exist (ignore failures)
    $PLISTBUDDY -c "Add :KeepAlive bool true" "$P" 2>/dev/null || \
      $PLISTBUDDY -c "Set :KeepAlive true" "$P" 2>/dev/null || true
    $PLISTBUDDY -c "Add :ProcessType string Background" "$P" 2>/dev/null || \
      $PLISTBUDDY -c "Set :ProcessType Background" "$P" 2>/dev/null || true

    # Reload per-user agent (needs gui/UID domain)
    USER_UID="$(id -u "$CONSOLE_USER" 2>/dev/null || echo 501)"
    launchctl bootout "gui/$USER_UID" "$P" >/dev/null 2>&1 || true
    launchctl bootstrap "gui/$USER_UID" "$P"
    launchctl kickstart -k "gui/$USER_UID/$(/usr/libexec/PlistBuddy -c 'Print :Label' "$P" 2>/dev/null || echo '')" \
      >/dev/null 2>&1 || true
  fi
done

# --- 5) Verification summary ---
echo "==> Verification:"
pmset -g | grep -E ' sleep|displaysleep|disksleep' | sed 's/^/    /'
echo "    keepawake status:"
launchctl print system/com.02luka.keepawake | grep -E 'state =|pid|last exit' | sed 's/^/    /'

echo "==> Headless mode enabled. Reboot recommended (or log out/in) to apply user defaults."
