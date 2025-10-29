# WO-251030-HEADLESS-MODE-RESTORE

**Owner:** CLC  
**Priority:** P0 (Reliability)  
**Created:** 2025-10-27 21:58:02+0000  
**Goal:** Restore *true headless* operation on Mac mini so that **all non-GUI agents keep running while the screen is locked or no monitor is attached**.

---

## Scope

1) Install a **root LaunchDaemon** that permanently prevents sleep: `caffeinate -dimsu`  
2) Normalize **power settings** for AC operation (`pmset -c`)  
3) **Migrate critical agents** from `~/Library/LaunchAgents` → `/Library/LaunchDaemons` so they survive screen lock / GUI logout  
4) Provide **verification** & **rollback** artifacts

> GUI-bound agents (e.g., Lisa/GUI runners) remain user-context and will only operate when a user session is active. Everything else must run headless.

---

## Deliverables

- `/Library/LaunchDaemons/com.02luka.caffeinate.plist` (root, KeepAlive)  
- `/Library/LaunchDaemons/com.02luka.<name>.plist` for critical agents migrated  
- `~/02luka/run/headless_restore.zsh` (installer)  
- `~/02luka/run/headless_verify.zsh` (verifier)  
- `~/02luka/run/headless_rollback.zsh` (rollback)  
- Report: `~/02luka/g/reports/251030_HEADLESS_RESTORE_DEPLOYED.md`

---

## Critical agents to migrate (system-level)

- `com.02luka.ops_atomic_monitor.loop`
- `com.02luka.reports.rotate`
- `com.02luka.redis_bridge`          *(if present / wanted)*
- `com.02luka.filebridge`            *(if present / wanted)*
- **Do NOT migrate** GUI automation agents (Lisa, Playwright, etc.)

---

## Implementation Script (create as `~/02luka/run/headless_restore.zsh`)

```zsh
#!/usr/bin/env zsh
set -euo pipefail

say_ok() { printf "✅ %s\n" "$1"; }
say_warn(){ printf "⚠️  %s\n" "$1"; }
say_do(){ printf "→ %s\n" "$1"; }

# 1) Root caffeinate LaunchDaemon
PLIST=/Library/LaunchDaemons/com.02luka.caffeinate.plist
sudo mkdir -p /Library/LaunchDaemons
sudo tee "$PLIST" >/dev/null <<'PL'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.02luka.caffeinate</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/caffeinate</string>
    <string>-dimsu</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
</dict>
</plist>
PL
sudo chown root:wheel "$PLIST"
sudo chmod 644 "$PLIST"
sudo launchctl unload "$PLIST" 2>/dev/null || true
sudo launchctl load -w "$PLIST"
say_ok "Caffeinate daemon installed & loaded."

# 2) AC power: never sleep
sudo pmset -c sleep 0 displaysleep 0 disksleep 0
say_ok "Power profile set for headless operation."

# 3) Migrate critical agents to LaunchDaemons
HOME_PL="$HOME/Library/LaunchAgents"
SYS_PL="/Library/LaunchDaemons"
CRITS=(
  com.02luka.ops_atomic_monitor.loop
  com.02luka.reports.rotate
  com.02luka.redis_bridge
  com.02luka.filebridge
)
for label in "${CRITS[@]}"; do
  SRC="$HOME_PL/${label}.plist"
  if [[ -f "$SRC" ]]; then
    say_do "Migrating $label to system daemons..."
    sudo launchctl unload "$SRC" 2>/dev/null || true
    sudo mv "$SRC" "$SYS_PL/${label}.plist"
    sudo chown root:wheel "$SYS_PL/${label}.plist"
    sudo chmod 644 "$SYS_PL/${label}.plist"
    sudo plutil -lint "$SYS_PL/${label}.plist" >/dev/null
    sudo launchctl load -w "$SYS_PL/${label}.plist"
    say_ok "Loaded $label (system)."
  else
    say_warn "Skip $label (not found in user LaunchAgents)."
  fi
done

# 4) Docker check (informational)
if pgrep -x Docker >/dev/null; then
  say_warn "Docker Desktop GUI detected. Consider brew-based daemon if you want pure headless."
fi

# 5) Display presence check (informational)
if system_profiler SPDisplaysDataType | grep -q "Display Type"; then
  say_ok "Display detected (or HDMI dummy present)."
else
  say_warn "No display detected. Non-GUI agents are fine; GUI automation will pause when locked."
fi

# 6) Write deployment report
mkdir -p "$HOME/02luka/g/reports"
{
  echo "# Headless Restore Deployed"
  echo "**Date:** $(date)"
  echo "- Caffeinate daemon: loaded"
  echo "- Power settings: AC sleep=0 displaysleep=0 disksleep=0"
  echo "- Migrated labels:"
  for l in "${CRITS[@]}"; do echo "  - $l"; done
} > "$HOME/02luka/g/reports/251030_HEADLESS_RESTORE_DEPLOYED.md"

say_ok "Headless restore complete."
```

⸻

Verification Script (create as ~/02luka/run/headless_verify.zsh)

```
#!/usr/bin/env zsh
set -euo pipefail
fail=0
check_loaded(){
  label="$1"
  domain="${2:-user}"
  if [[ "$domain" == system ]]; then
    if sudo launchctl print "system/$label" >/dev/null 2>&1; then
      echo "✅ $label loaded (system)"
      return
    fi
    if sudo launchctl list | grep -q "$label"; then
      echo "✅ $label loaded (system)"
      return
    fi
  else
    if launchctl list | grep -q "$label"; then
      echo "✅ $label loaded"
      return
    fi
  fi
  echo "❌ $label NOT loaded"; fail=1
}

echo "=== Verify Headless Mode ==="
if [[ -f "/Library/LaunchDaemons/com.02luka.caffeinate.plist" ]]; then
  check_loaded com.02luka.caffeinate system
else
  check_loaded com.02luka.caffeinate
fi
for l in \
  com.02luka.ops_atomic_monitor.loop \
  com.02luka.reports.rotate \
  com.02luka.redis_bridge \
  com.02luka.filebridge
  do
  if [[ -f "/Library/LaunchDaemons/${l}.plist" ]]; then
    check_loaded "$l" system
  fi
done

pmset -g custom | grep -A1 "AC Power" | sed 's/^/  /'
echo "Note: GUI agents are expected to be idle while locked."
exit $fail
```

⸻

Rollback Script (create as ~/02luka/run/headless_rollback.zsh)

```
#!/usr/bin/env zsh
set -euo pipefail
echo "Rolling back headless migration..."
for l in \
  com.02luka.ops_atomic_monitor.loop \
  com.02luka.reports.rotate \
  com.02luka.redis_bridge \
  com.02luka.filebridge
do
  if [[ -f "/Library/LaunchDaemons/${l}.plist" ]]; then
    sudo launchctl unload "/Library/LaunchDaemons/${l}.plist" || true
    sudo mv "/Library/LaunchDaemons/${l}.plist" "$HOME/Library/LaunchAgents/${l}.plist"
    launchctl load -w "$HOME/Library/LaunchAgents/${l}.plist" || true
    echo "↩︎ $l restored to user LaunchAgents."
  fi
done

if [[ -f /Library/LaunchDaemons/com.02luka.caffeinate.plist ]]; then
  sudo launchctl unload /Library/LaunchDaemons/com.02luka.caffeinate.plist || true
  sudo rm -f /Library/LaunchDaemons/com.02luka.caffeinate.plist
  echo "↩︎ caffeinate daemon removed."
fi
echo "Rollback done."
```

⸻

Acceptance Criteria
•com.02luka.caffeinate is loaded (root) and persists across lock/unlock
•AC power profile shows sleep=0, displaysleep=0, disksleep=0
•Critical agents appear under /Library/LaunchDaemons and remain running when the screen is locked
•~/02luka/g/reports/251030_HEADLESS_RESTORE_DEPLOYED.md exists with success details
•~/02luka/run/headless_verify.zsh returns exit 0

⸻

Runbook (CLC)
1.Create scripts from this WO
2.chmod +x ~/02luka/run/headless_*.zsh
3.Execute: ~/02luka/run/headless_restore.zsh
4.Verify:  ~/02luka/run/headless_verify.zsh
5.Lock screen for 10+ minutes; re-verify agents stayed active
6.File the deployment report

End of Work Order
