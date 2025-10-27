#!/usr/bin/env zsh
set -euo pipefail

if [[ "$(uname)" != "Darwin" ]]; then
  echo "This utility is intended for macOS hosts only." >&2
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
  echo "Requesting sudo for system modifications..."
  exec sudo -E zsh "$0" "$@"
fi

echo "🚀 Restoring Headless Mode for Mac mini..."

ACTIVE_USER="${SUDO_USER:-$USER}"
USER_HOME="$(dscl . -read /Users/"$ACTIVE_USER" NFSHomeDirectory 2>/dev/null | awk '{print $2}')"
if [[ -z "$USER_HOME" || ! -d "$USER_HOME" ]]; then
  USER_HOME="$(eval echo "~$ACTIVE_USER")"
fi

# Fallback to root home if we cannot resolve the active user (e.g. CI runs)
if [[ -z "$USER_HOME" || ! -d "$USER_HOME" ]]; then
  USER_HOME="$HOME"
fi

ACTIVE_UID="$(id -u "$ACTIVE_USER" 2>/dev/null || echo 0)"

# 1. Keep system awake at all times
mkdir -p /Library/LaunchDaemons
cat >/Library/LaunchDaemons/com.02luka.caffeinate.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" 
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.02luka.caffeinate</string>
  <key>ProgramArguments</key>
  <array><string>/usr/bin/caffeinate</string><string>-dimsu</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
</dict>
</plist>
PLIST
chmod 644 /Library/LaunchDaemons/com.02luka.caffeinate.plist
chown root:wheel /Library/LaunchDaemons/com.02luka.caffeinate.plist
launchctl bootout system/com.02luka.caffeinate >/dev/null 2>&1 || true
launchctl bootstrap system /Library/LaunchDaemons/com.02luka.caffeinate.plist || true
launchctl kickstart -k system/com.02luka.caffeinate >/dev/null 2>&1 || true
echo "✅ Caffeinate daemon installed and active."

# 2. Move critical agents (Redis, OPS Monitor, FileBridge) to LaunchDaemons
CRITICAL_AGENTS=(ops_atomic_monitor.loop redis_bridge filebridge)
for name in $CRITICAL_AGENTS; do
  SRC="$USER_HOME/Library/LaunchAgents/com.02luka.$name.plist"
  DST="/Library/LaunchDaemons/com.02luka.$name.plist"
  if [[ -f "$SRC" ]]; then
    echo "→ Migrating $name to LaunchDaemons..."
    launchctl bootout gui/$ACTIVE_UID "$SRC" >/dev/null 2>&1 || true
    mv "$SRC" "$DST"
    chmod 644 "$DST"
    chown root:wheel "$DST"
    launchctl bootstrap system "$DST" || true
    launchctl kickstart -k system/com.02luka.$name >/dev/null 2>&1 || true
  elif [[ -f "$DST" ]]; then
    echo "→ $name already managed under LaunchDaemons."
    launchctl bootstrap system "$DST" >/dev/null 2>&1 || true
    launchctl kickstart -k system/com.02luka.$name >/dev/null 2>&1 || true
  else
    echo "→ $name agent not found; skipping."
  fi
done

# 3. Verify HDMI or dummy display
echo "🔍 Checking display presence..."
if system_profiler SPDisplaysDataType | grep -q "Display Type"; then
  echo "✅ Display detected."
else
  echo "⚠️ No display detected — recommend HDMI dummy plug for GUI agents."
fi

# 4. Docker service check
if pgrep -x Docker >/dev/null; then
  echo "⚠️ Docker Desktop detected (GUI). Consider switching to brew daemon:"
  echo "   brew install --cask docker && brew services start docker"
else
  if pgrep -x com.docker.hyperkit >/dev/null || pgrep -x dockerd >/dev/null; then
    echo "✅ Docker daemon ready for headless use."
  else
    echo "⚠️ Docker daemon not detected. Start via 'brew services start docker' or equivalent."
  fi
fi

# 5. Power settings verification
echo "🔧 Ensuring system never sleeps on AC..."
pmset -c sleep 0 displaysleep 0 disksleep 0

# 6. Final summary
echo "\n✅ Headless mode restored."
echo "All core daemons will run even when screen is locked."
echo "GUI agents (Lisa, Hybrid) will resume only when you unlock."
