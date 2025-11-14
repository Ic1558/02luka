# Feature Plan: Health Dashboard Auto-Update

**Feature ID:** `health-dashboard-auto-update`  
**Date:** 2025-11-12  
**Status:** Planning → Implementation Ready

**Related:** [SPEC.md](./feature_health_dashboard_auto_update_SPEC.md)

---

## Overview

Implement automatic periodic updates for the health dashboard via macOS LaunchAgent, ensuring `g/reports/health_dashboard.json` stays current without manual intervention.

**Estimated Effort:** 1-2 hours  
**Complexity:** Low  
**Risk:** Low

---

## Task Breakdown

### Phase 1: LaunchAgent Creation ✅

**Tasks:**
1. ✅ Create LaunchAgent plist file
   - File: `LaunchAgents/com.02luka.health.dashboard.plist`
   - Label: `com.02luka.health.dashboard`
   - Schedule: `StartInterval: 1800` (30 minutes)
   - Command: `node "$HOME/02luka/run/health_dashboard.cjs" || true`
   - Logs: `~/02luka/logs/health_dashboard.{out,err}.log`

2. ✅ Validate plist syntax
   - Run `plutil -lint` on plist file
   - Ensure XML is well-formed

3. ✅ Follow 02luka patterns
   - Include `ThrottleInterval: 30`
   - Set proper `PATH` environment variable
   - Use absolute paths where possible
   - `RunAtLoad: true`, `KeepAlive: false`

### Phase 2: Installation & Verification ✅

**Tasks:**
1. ✅ Create installation script
   - File: `tools/install_health_dashboard_launchagent.zsh`
   - Copy plist to `~/Library/LaunchAgents/`
   - Load LaunchAgent with `launchctl load`
   - Verify with `launchctl list`

2. ✅ Create verification script
   - File: `tools/verify_health_dashboard_launchagent.zsh`
   - Check LaunchAgent is loaded
   - Verify logs are being written
   - Test manual kickstart

3. ✅ Create uninstall script (optional)
   - File: `tools/uninstall_health_dashboard_launchagent.zsh`
   - Unload LaunchAgent
   - Remove plist file
   - Clean up logs (optional)

### Phase 3: Testing & Documentation ✅

**Tasks:**
1. ✅ Manual testing
   - Install LaunchAgent
   - Wait 30 minutes, verify dashboard updated
   - Check logs for execution
   - Test error handling (temporarily break script)

2. ✅ Integration testing
   - Verify dashboard updates on system reboot
   - Verify updates continue after script errors
   - Verify log rotation works

3. ✅ Documentation
   - Update system documentation
   - Add LaunchAgent to inventory
   - Document installation process

---

## Implementation Details

### LaunchAgent Plist Structure

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.02luka.health.dashboard</string>
  
  <key>ProgramArguments</key>
  <array>
    <string>/bin/zsh</string>
    <string>-lc</string>
    <string>node "$HOME/02luka/run/health_dashboard.cjs" || true</string>
  </array>
  
  <key>StartInterval</key>
  <integer>1800</integer>
  
  <key>RunAtLoad</key>
  <true/>
  
  <key>KeepAlive</key>
  <false/>
  
  <key>ThrottleInterval</key>
  <integer>30</integer>
  
  <key>StandardOutPath</key>
  <string>$HOME/02luka/logs/health_dashboard.out.log</string>
  
  <key>StandardErrorPath</key>
  <string>$HOME/02luka/logs/health_dashboard.err.log</string>
  
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
  </dict>
</dict>
</plist>
```

### Installation Script Pattern

```zsh
#!/usr/bin/env zsh
set -euo pipefail

REPO="${LUKA_SOT:-$HOME/02luka}"
PLIST_SRC="$REPO/LaunchAgents/com.02luka.health.dashboard.plist"
PLIST_DEST="$HOME/Library/LaunchAgents/com.02luka.health.dashboard.plist"

# Copy plist
cp "$PLIST_SRC" "$PLIST_DEST"

# Validate
plutil -lint "$PLIST_DEST" || exit 1

# Load LaunchAgent
launchctl unload "$PLIST_DEST" 2>/dev/null || true
launchctl load "$PLIST_DEST"

# Verify
launchctl list | grep "com.02luka.health.dashboard" || {
  echo "❌ LaunchAgent not loaded"
  exit 1
}

echo "✅ Health Dashboard LaunchAgent installed"
```

---

## Test Strategy

### Unit Tests

**Test 1: Plist Validation**
```bash
plutil -lint LaunchAgents/com.02luka.health.dashboard.plist
# Expected: OK
```

**Test 2: Script Execution**
```bash
node ~/02luka/run/health_dashboard.cjs
# Expected: ✅ health_dashboard written: ...
# Verify: JSON is valid and recent
```

### Integration Tests

**Test 3: LaunchAgent Installation**
```bash
tools/install_health_dashboard_launchagent.zsh
launchctl list | grep "com.02luka.health.dashboard"
# Expected: LaunchAgent listed
```

**Test 4: Automatic Execution**
```bash
# Install LaunchAgent
tools/install_health_dashboard_launchagent.zsh

# Note current timestamp
TIMESTAMP1=$(jq -r '.generated_at' g/reports/health_dashboard.json)

# Wait 30 minutes OR manually trigger
launchctl kickstart gui/$(id -u)/com.02luka.health.dashboard

# Wait 5 seconds
sleep 5

# Check new timestamp
TIMESTAMP2=$(jq -r '.generated_at' g/reports/health_dashboard.json)

# Verify updated
[[ "$TIMESTAMP1" != "$TIMESTAMP2" ]] && echo "✅ Dashboard updated" || echo "❌ Dashboard not updated"
```

**Test 5: Error Handling**
```bash
# Temporarily rename script
mv run/health_dashboard.cjs run/health_dashboard.cjs.bak

# Wait for execution (or kickstart)
launchctl kickstart gui/$(id -u)/com.02luka.health.dashboard
sleep 2

# Check logs for error
tail -5 ~/02luka/logs/health_dashboard.err.log
# Expected: Error message, but LaunchAgent still running

# Restore script
mv run/health_dashboard.cjs.bak run/health_dashboard.cjs
```

**Test 6: System Reboot**
```bash
# Install LaunchAgent
tools/install_health_dashboard_launchagent.zsh

# Reboot system (manual)
# After reboot, verify:
launchctl list | grep "com.02luka.health.dashboard"
# Expected: LaunchAgent loaded

# Check dashboard was updated on startup
jq -r '.generated_at' g/reports/health_dashboard.json
# Expected: Recent timestamp (within last few minutes)
```

### Regression Tests

**Test 7: Existing Functionality**
```bash
# Verify manual execution still works
node run/health_dashboard.cjs
# Expected: ✅ health_dashboard written

# Verify JSON is valid
jq . g/reports/health_dashboard.json >/dev/null
# Expected: No errors
```

---

## Rollback Plan

If issues occur:

1. **Unload LaunchAgent:**
   ```bash
   launchctl unload ~/Library/LaunchAgents/com.02luka.health.dashboard.plist
   ```

2. **Remove plist:**
   ```bash
   rm ~/Library/LaunchAgents/com.02luka.health.dashboard.plist
   ```

3. **Manual execution still works:**
   ```bash
   node ~/02luka/run/health_dashboard.cjs
   ```

**Impact:** Low - Feature is additive, doesn't modify existing functionality

---

## Deployment Checklist

- [ ] Create LaunchAgent plist file
- [ ] Validate plist syntax
- [ ] Create installation script
- [ ] Create verification script
- [ ] Test manual execution
- [ ] Test LaunchAgent installation
- [ ] Test automatic execution (kickstart)
- [ ] Test error handling
- [ ] Test system reboot
- [ ] Update documentation
- [ ] Code review
- [ ] Deploy to production

---

## Success Metrics

1. ✅ LaunchAgent installed and running
2. ✅ Dashboard updates every 30 minutes automatically
3. ✅ Dashboard updates on system startup
4. ✅ Logs capture execution and errors
5. ✅ No manual intervention required
6. ✅ Zero impact on existing functionality

---

## Timeline

- **Phase 1:** 30 minutes (LaunchAgent creation)
- **Phase 2:** 30 minutes (Installation scripts)
- **Phase 3:** 30 minutes (Testing & documentation)
- **Total:** ~1.5 hours

---

**Plan Status:** ✅ **READY FOR IMPLEMENTATION**
