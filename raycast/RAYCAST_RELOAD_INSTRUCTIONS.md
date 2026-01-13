# Raycast Script Reload Instructions

## Issue
Control+A hotkey opens command but doesn't auto-run (waits for Enter)

## Root Cause
Raycast cached old script metadata with @raycast.argument

## Fix Steps

### 1. Verify Script Header
```bash
head -10 ~/02luka/raycast/atg-snapshot.command
```

Should show:
- ✅ NO @raycast.argument line
- ✅ @raycast.mode silent
- ✅ @raycast.needsConfirmation false

### 2. Force Raycast Reload

**Option A: Toggle Script**
1. Open Raycast Settings (⌘,)
2. Go to Extensions → Scripts
3. Find "ATG Snapshot"
4. Disable (uncheck)
5. Wait 2 seconds
6. Enable (check)

**Option B: Restart Raycast**
1. Quit Raycast completely (⌘Q from menu bar)
2. Wait 3 seconds
3. Relaunch Raycast

**Option C: Clear Script Cache** (Nuclear option)
```bash
rm -rf ~/Library/Caches/com.raycast.macos/
killall Raycast
open -a Raycast
```

### 3. Test Auto-Run

Press Control+A

**Expected**: Script runs immediately, no input prompt
**Actual (if broken)**: Input cursor appears, waiting for Enter

### 4. If Still Not Working

Check Raycast logs:
```bash
log show --predicate 'subsystem == "com.raycast.macos"' --last 5m | grep -i script
```

Or create minimal test script:
```bash
cat > ~/02luka/raycast/test-autorun.command <<'SCRIPT'
#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Test Auto Run
# @raycast.mode silent
echo "Auto-run works!"
SCRIPT
chmod +x ~/02luka/raycast/test-autorun.command
```

Assign hotkey to test-autorun, then test if THAT auto-runs.
If test works but ATG doesn't → specific script issue
If test also fails → Raycast configuration issue

