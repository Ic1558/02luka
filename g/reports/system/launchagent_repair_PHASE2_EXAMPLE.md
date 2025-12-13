# Phase 2 Example: Complete Walkthrough for 1 Service
**Service:** `com.02luka.health_monitor`  
**Scenario:** FIX (old path found, needs update)  
**Time:** ~5-10 minutes

---

## Step 1: Investigate

```bash
cd ~/02luka
./tools/launchagent_investigate_core.zsh
```

**Output for `com.02luka.health_monitor`:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 Service: com.02luka.health_monitor

  Status: Exit code 78
  ✅ Plist exists: /Users/icmini/Library/LaunchAgents/com.02luka.health_monitor.plist
  Script: /Users/icmini/LocalProjects/02luka_local_g/g/tools/health_monitor.zsh
  ⚠️  OLD PATH DETECTED (needs update)
  ❌ Script file MISSING: /Users/icmini/LocalProjects/02luka_local_g/g/tools/health_monitor.zsh
  ✅ Log directory exists: /Users/icmini/02luka/logs
```

**Analysis:**
- Exit 78 = Config error (path issue)
- Old path detected: `/Users/icmini/LocalProjects/02luka_local_g`
- Script missing at old location
- Need to check if script exists at new location

---

## Step 2: Answer Questions

**Q1: Still needed?**  
→ **YES** (health monitoring is core functionality)

**Q2: Path/script/log ready?**  
→ **NO** (old path in plist, need to check new location)

**Q3: REMOVE or ARCHIVE?**  
→ **N/A** (keeping it)

**Decision:** **FIX**

---

## Step 3: Check Current State

```bash
SERVICE="com.02luka.health_monitor"

# Check plist content
cat ~/Library/LaunchAgents/${SERVICE}.plist

# Check if script exists at new location
NEW_SCRIPT="/Users/icmini/02luka/tools/health_monitor.zsh"
OLD_SCRIPT="/Users/icmini/LocalProjects/02luka_local_g/g/tools/health_monitor.zsh"

if [[ -f "$NEW_SCRIPT" ]]; then
  echo "✅ Script exists at new location: $NEW_SCRIPT"
elif [[ -f "$OLD_SCRIPT" ]]; then
  echo "⚠️  Script still at old location: $OLD_SCRIPT"
else
  echo "❌ Script not found at either location"
fi

# Check current launchctl status
launchctl list | grep "$SERVICE"
```

**Expected output:**
```
<pid> 78 com.02luka.health_monitor
```

Exit code 78 confirms config error.

---

## Step 4: Fix Plist

```bash
SERVICE="com.02luka.health_monitor"
PLIST="$HOME/Library/LaunchAgents/${SERVICE}.plist"

# Backup original
cp "$PLIST" "${PLIST}.backup_$(date +%Y%m%d_%H%M%S)"

# Check current script path
CURRENT_SCRIPT=$(plutil -extract ProgramArguments.1 raw "$PLIST" 2>/dev/null)
echo "Current script: $CURRENT_SCRIPT"

# Determine new script path
# If old path: /Users/icmini/LocalProjects/02luka_local_g/g/tools/health_monitor.zsh
# New path: /Users/icmini/02luka/tools/health_monitor.zsh

NEW_SCRIPT="/Users/icmini/02luka/tools/health_monitor.zsh"

# Verify new script exists
if [[ ! -f "$NEW_SCRIPT" ]]; then
  echo "❌ New script not found: $NEW_SCRIPT"
  echo "👉 Need to create or locate script first"
  exit 1
fi

# Update plist using plutil
plutil -replace ProgramArguments.1 -string "$NEW_SCRIPT" "$PLIST"

# Update log paths if needed
OLD_LOG_BASE="/Users/icmini/LocalProjects/02luka_local_g/logs"
NEW_LOG_BASE="/Users/icmini/02luka/logs"

# Check and update StandardOutPath
CURRENT_STDOUT=$(plutil -extract StandardOutPath raw "$PLIST" 2>/dev/null || echo "")
if [[ -n "$CURRENT_STDOUT" ]] && [[ "$CURRENT_STDOUT" == *"$OLD_LOG_BASE"* ]]; then
  NEW_STDOUT="${CURRENT_STDOUT//$OLD_LOG_BASE/$NEW_LOG_BASE}"
  plutil -replace StandardOutPath -string "$NEW_STDOUT" "$PLIST"
  echo "✅ Updated StandardOutPath: $NEW_STDOUT"
fi

# Check and update StandardErrorPath
CURRENT_STDERR=$(plutil -extract StandardErrorPath raw "$PLIST" 2>/dev/null || echo "")
if [[ -n "$CURRENT_STDERR" ]] && [[ "$CURRENT_STDERR" == *"$OLD_LOG_BASE"* ]]; then
  NEW_STDERR="${CURRENT_STDERR//$OLD_LOG_BASE/$NEW_LOG_BASE}"
  plutil -replace StandardErrorPath -string "$NEW_STDERR" "$PLIST"
  echo "✅ Updated StandardErrorPath: $NEW_STDERR"
fi

# Verify plist is valid
plutil -lint "$PLIST" && echo "✅ Plist is valid"
```

---

## Step 5: Make Script Executable

```bash
chmod +x "$NEW_SCRIPT"
test -x "$NEW_SCRIPT" && echo "✅ Script is executable"
```

---

## Step 6: Reload Service

```bash
SERVICE="com.02luka.health_monitor"

# Unload old service
launchctl bootout "gui/$(id -u)/$SERVICE" 2>/dev/null || true

# Wait a moment
sleep 1

# Load new service
launchctl bootstrap "gui/$(id -u)" ~/Library/LaunchAgents/${SERVICE}.plist

# Verify load succeeded
if launchctl list | grep -q "$SERVICE"; then
  echo "✅ Service loaded"
else
  echo "❌ Service failed to load"
  exit 1
fi
```

---

## Step 7: Verify Fix

```bash
SERVICE="com.02luka.health_monitor"

# Check exit code
EXIT_CODE=$(launchctl list | grep "^[[:space:]]*[0-9]*[[:space:]]*[0-9]*[[:space:]]*$SERVICE" | awk '{print $2}')

if [[ "$EXIT_CODE" == "0" ]]; then
  echo "✅ Service running (exit code 0)"
elif [[ "$EXIT_CODE" == "78" ]]; then
  echo "⚠️  Still config error (78) - check plist again"
  cat ~/Library/LaunchAgents/${SERVICE}.plist
elif [[ -n "$EXIT_CODE" ]]; then
  echo "⚠️  Exit code: $EXIT_CODE - check logs"
  tail -20 ~/02luka/logs/${SERVICE}.log 2>/dev/null || echo "No log file"
else
  echo "❌ Service not found in launchctl list"
fi

# Check recent log for errors
if [[ -f ~/02luka/logs/${SERVICE}.log ]]; then
  echo ""
  echo "Recent log entries:"
  tail -5 ~/02luka/logs/${SERVICE}.log
fi
```

**Expected result:**
```
✅ Service running (exit code 0)
```

---

## Step 8: Update STATUS.md

Edit: `g/reports/system/launchagent_repair_PHASE2_STATUS.md`

**Before:**
```markdown
| `com.02luka.health_monitor` | ⏳ PENDING | - | System health monitoring |
```

**After:**
```markdown
| `com.02luka.health_monitor` | ✅ FIXED | FIX | Updated paths from old to new SOT, script executable, verified exit 0 |
```

---

## Step 9: Commit Progress

```bash
cd ~/02luka

git add g/reports/system/launchagent_repair_PHASE2_STATUS.md
git add ~/Library/LaunchAgents/com.02luka.health_monitor.plist

git commit -m "fix(system): Phase 2A - health_monitor FIX

- Updated plist paths: /Users/icmini/LocalProjects/02luka_local_g → /Users/icmini/02luka
- Updated script path: tools/health_monitor.zsh
- Updated log paths to new SOT
- Made script executable
- Verified: launchctl list shows exit 0"
```

---

## Step 10: Verify Commit

```bash
git log -1 --oneline
git show --stat
```

---

## ✅ Complete

**Time taken:** ~5-10 minutes  
**Result:** Service fixed and verified  
**Next:** Repeat for remaining 6 core services

---

## 📝 Notes

- **Always backup plist** before editing (`.backup_YYYYMMDD_HHMMSS`)
- **Verify script exists** at new location before updating plist
- **Test immediately** after reload (check exit code)
- **Update STATUS.md** before moving to next service
- **Commit frequently** (every 1-3 services)

---

**See also:**
- `launchagent_repair_PHASE2_QUICK_CHECKLIST.md` - Quick reference
- `launchagent_repair_PHASE2_SAFE_START.md` - Full guide
- `launchagent_repair_PHASE2_STATUS.md` - Progress tracker
