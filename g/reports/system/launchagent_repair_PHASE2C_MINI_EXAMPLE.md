# Phase 2C-Mini: Example Walkthrough - `com.02luka.mary-coo`

**Service:** `com.02luka.mary-coo`  
**Exit Code:** 2 (Error)  
**Priority:** HIGH (affects delegation orchestrator)

---

## Step 1: Pre-Flight Check

```bash
cd ~/02luka

# Check current status
launchctl list | grep "mary-coo"
# Expected: Shows exit code 2

# Check plist exists
ls ~/Library/LaunchAgents/com.02luka.mary-coo.plist
# Expected: File exists

# Check log exists
ls ~/02luka/logs/mary-coo*.log 2>/dev/null || echo "No log found"
```

---

## Step 2: Read Plist

```bash
plutil -p ~/Library/LaunchAgents/com.02luka.mary-coo.plist
```

**Expected output structure:**
```
{
  "Label" => "com.02luka.mary-coo"
  "ProgramArguments" => [
    0 => "/bin/zsh"
    1 => "-lc"
    2 => "cd /Users/icmini/LocalProjects/02luka_local_g && ..."
  ]
  "StandardOutPath" => "/Users/icmini/LocalProjects/02luka_local_g/logs/mary-coo.log"
  "StandardErrorPath" => "/Users/icmini/LocalProjects/02luka_local_g/logs/mary-coo.err.log"
  ...
}
```

**Look for:**
- Old path: `/Users/icmini/LocalProjects/02luka_local_g`
- Should be: `/Users/icmini/02luka` or `~/02luka`

---

## Step 3: Extract Script Path

From `ProgramArguments`, identify the actual script being called.

**If structure is:**
- `ProgramArguments.0` = `/bin/zsh`
- `ProgramArguments.1` = `-lc`
- `ProgramArguments.2` = `"cd /old/path && ./script.zsh"`

**Extract script:** Look for `./script.zsh` or `python3 script.py` in the command string.

---

## Step 4: Check Script Exists

```bash
# Example: If script is ~/02luka/agents/mary_coo/mary_coo.py
SCRIPT_PATH="$HOME/02luka/agents/mary_coo/mary_coo.py"
test -f "$SCRIPT_PATH" && echo "✅ Script exists" || echo "❌ Script missing"
test -x "$SCRIPT_PATH" && echo "✅ Script executable" || echo "⚠️  Script not executable"
```

---

## Step 5: Check Logs

```bash
# Check recent errors
tail -20 ~/02luka/logs/mary-coo*.log 2>/dev/null || echo "No log file"

# Look for:
# - FileNotFoundError
# - ImportError
# - Permission denied
# - Old path references
```

---

## Step 6: Decision (Q1-Q3)

**Q1: Still needed?**
- Check `02luka.md` for "mary-coo" or "Mary COO"
- Check if it's part of current delegation architecture
- **Answer:** Y (if in architecture) / N (if obsolete) / DEFER (if unsure)

**Q2: If yes, path/script correct?**
- Script exists at new path?
- Script executable?
- **Answer:** Y (if all good) / N (if needs fixing)

**Q3: If no, REMOVE or ARCHIVE?**
- REMOVE: Completely obsolete, no dependencies
- ARCHIVE: Might be needed later, or has dependencies
- **Answer:** REMOVE / ARCHIVE

---

## Step 7: Action - FIX Example

```bash
SERVICE="com.02luka.mary-coo"
PLIST="$HOME/Library/LaunchAgents/${SERVICE}.plist"

# Bootout first
launchctl bootout "gui/$(id -u)/$SERVICE" 2>/dev/null || true

# Update paths using plutil
plutil -replace "ProgramArguments.2" -string "cd ~/02luka && ./agents/mary_coo/mary_coo.py" "$PLIST"
plutil -replace "StandardOutPath" -string "$HOME/02luka/logs/mary-coo.log" "$PLIST"
plutil -replace "StandardErrorPath" -string "$HOME/02luka/logs/mary-coo.err.log" "$PLIST"

# Make script executable (if needed)
chmod +x ~/02luka/agents/mary_coo/mary_coo.py

# Validate plist
plutil -lint "$PLIST" && echo "✅ Plist valid" || echo "❌ Plist invalid"

# Reload
launchctl bootstrap "gui/$(id -u)" "$PLIST"
```

---

## Step 8: Action - REMOVE Example

```bash
SERVICE="com.02luka.mary-coo"
PLIST="$HOME/Library/LaunchAgents/${SERVICE}.plist"
ARCHIVE_DIR="$HOME/02luka/_plists_archive_20251207"

# Bootout
launchctl bootout "gui/$(id -u)/$SERVICE" 2>/dev/null || true

# Archive plist
mkdir -p "$ARCHIVE_DIR"
mv "$PLIST" "$ARCHIVE_DIR/" && echo "✅ Archived" || echo "⚠️  Already removed"
```

---

## Step 9: Verification

```bash
# Check exit code
launchctl list | grep "mary-coo"
# Expected after FIX: Exit 0
# Expected after REMOVE: Not in list

# Check log (if FIXED)
tail -10 ~/02luka/logs/mary-coo.log
# Expected: No errors, service running
```

---

## Step 10: Update STATUS.md

Edit `g/reports/system/launchagent_repair_PHASE2_STATUS.md`:

```markdown
| `com.02luka.mary-coo` | ✅ FIXED | FIX | Updated paths to ~/02luka, exit 0 |
```

or

```markdown
| `com.02luka.mary-coo` | ✅ REMOVED | REMOVE | Obsolete - replaced by gateway v3 |
```

---

## Step 11: Commit

```bash
cd ~/02luka
git add g/reports/system/launchagent_repair_PHASE2_STATUS.md
git commit -m "fix(system): Phase 2C-mini - mary-coo FIXED/REMOVED

- Updated paths to ~/02luka
- Made script executable
- Verified exit 0

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Common Issues & Solutions

### Issue: Script not found
**Solution:** Check if script moved or renamed. Search codebase for similar functionality.

### Issue: ImportError in Python script
**Solution:** Check PYTHONPATH, virtualenv, or dependencies. May need to update script itself.

### Issue: Permission denied
**Solution:** `chmod +x <script_path>`

### Issue: Old path in command string
**Solution:** Use `plutil -replace` to update `ProgramArguments.2` (or appropriate index).

---

**Next:** Repeat for `delegation-watchdog` and `clc-executor`
