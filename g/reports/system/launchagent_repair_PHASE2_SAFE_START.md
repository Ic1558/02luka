# Phase 2 Safe Start Checklist
**Created:** 2025-12-07  
**Purpose:** Step-by-step guide for safely starting Phase 2 LaunchAgent repair

---

## ✅ Pre-Flight Checks

Before starting Phase 2, verify:

- [ ] Phase 1 is complete (ghost services removed, duplicate plist removed)
- [ ] `tools/launchagent_cleanup_ghosts.zsh` has been executed successfully
- [ ] `launchctl list | grep "com.02luka" | awk '$2 == "127"' | wc -l` returns `0`
- [ ] All Phase 2 tools exist:
  - [ ] `tools/launchagent_investigate_core.zsh`
  - [ ] `tools/launchagent_quick_start.zsh`
  - [ ] `g/reports/system/launchagent_repair_PHASE2_STATUS.md`
- [ ] Backup directory ready: `~/02luka/_plists_archive_20251207/` (will be created if needed)

---

## 🚀 Recommended Start: Core Services First

### Step 1: Run Investigation

```bash
cd ~/02luka
./tools/launchagent_quick_start.zsh
# Choose: 1 (Core Only)
```

This will:
- Check all 7 core services
- Report plist existence, script paths, old path references
- Verify executability and log directories
- Show recent errors from logs

### Step 2: Open Status Tracker

Keep this file open in Cursor:
```
g/reports/system/launchagent_repair_PHASE2_STATUS.md
```

### Step 3: Process Each Service

For each of the 7 core services:

1. **Review investigation output** for that service
2. **Answer the 3 key questions:**
   - Q1: Still needed in current architecture? (Y/N/DEFER)
   - Q2: If yes: Path/script exists and config correct? (Y/N)
   - Q3: If no: Remove or archive? (REMOVE/ARCHIVE)
3. **Check technical details:**
   - Q4: Old path reference found? (Y/N)
   - Q5: Script file exists? (Y/N)
   - Q6: Script executable? (Y/N)
   - Q7: Log directory exists? (Y/N)
   - Q8: Recent errors in log? (Y/N)
4. **Make decision:**
   - **FIX** - Service needed, fix paths/config
   - **REMOVE** - Service obsolete, remove completely
   - **ARCHIVE** - Service obsolete, move to archive
   - **DEFER** - Service needed but low priority, fix later
5. **Update STATUS.md:**
   - Change Status: `PENDING` → `IN_PROGRESS`
   - Add Decision: `FIX` / `REMOVE` / `ARCHIVE` / `DEFER`
   - Add Notes: Brief explanation of decision

### Step 4: Execute Decisions

#### For FIX:
```bash
SERVICE="com.02luka.health_monitor"
# 1. Check current plist
cat ~/Library/LaunchAgents/${SERVICE}.plist

# 2. Fix paths (if old path found)
# Edit plist to use /Users/icmini/02luka instead of /Users/icmini/LocalProjects/02luka_local_g

# 3. Verify script exists and is executable
SCRIPT_PATH=$(plutil -extract ProgramArguments.1 raw ~/Library/LaunchAgents/${SERVICE}.plist)
test -f "$SCRIPT_PATH" && chmod +x "$SCRIPT_PATH"

# 4. Unload and reload
launchctl bootout "gui/$(id -u)/$SERVICE" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" ~/Library/LaunchAgents/${SERVICE}.plist

# 5. Verify
launchctl list | grep "$SERVICE"
```

#### For REMOVE:
```bash
SERVICE="com.02luka.obsolete_service"
# 1. Unload service
launchctl bootout "gui/$(id -u)/$SERVICE" 2>/dev/null || true

# 2. Remove plist
rm ~/Library/LaunchAgents/${SERVICE}.plist

# 3. Verify
launchctl list | grep "$SERVICE" || echo "✅ Removed"
```

#### For ARCHIVE:
```bash
SERVICE="com.02luka.legacy_service"
ARCHIVE_DIR="$HOME/02luka/_plists_archive_20251207"
mkdir -p "$ARCHIVE_DIR"

# 1. Unload service
launchctl bootout "gui/$(id -u)/$SERVICE" 2>/dev/null || true

# 2. Move plist to archive
mv ~/Library/LaunchAgents/${SERVICE}.plist "$ARCHIVE_DIR/"

# 3. Verify
ls "$ARCHIVE_DIR/${SERVICE}.plist" && echo "✅ Archived"
```

#### For DEFER:
- Mark in STATUS.md with `DEFER` decision
- Add note explaining why (e.g., "Low priority, will fix in Phase 2B")
- No action needed now

### Step 5: Update Progress

After processing each service:
1. Update STATUS.md: `IN_PROGRESS` → `FIXED` / `REMOVED` / `ARCHIVED` / `DEFERRED`
2. Commit progress:
   ```bash
   git add g/reports/system/launchagent_repair_PHASE2_STATUS.md
   git commit -m "fix(system): Phase 2A - <service> <decision>"
   ```

---

## 📊 Progress Tracking

### Phase 2A: Core Services (7 total)

After each session, update:
- **Fixed:** X/7
- **Removed:** X/7
- **Archived:** X/7
- **Deferred:** X/7

### Success Criteria

Phase 2A is complete when:
- All 7 core services have Status = `FIXED` / `REMOVED` / `ARCHIVED` / `DEFERRED`
- No services remain `PENDING` or `IN_PROGRESS`
- All decisions documented in STATUS.md
- All removed/archived plists moved to archive directory

---

## ⚠️ Safety Rules

1. **Never remove a service without investigation**
   - Always check logs first
   - Verify it's truly obsolete
   - Check if it's referenced in `02luka.md` or other docs

2. **Always backup before removing**
   - Archive (move to `_plists_archive_20251207/`) is safer than delete
   - Can restore later if needed

3. **Test after fixing**
   - After fixing a service, verify it runs:
   ```bash
   launchctl list | grep "$SERVICE"
   # Check exit code is 0 (not 78, 1, 2, 254)
   ```

4. **One service at a time**
   - Don't batch process multiple services
   - Fix → Test → Commit → Next

5. **Document decisions**
   - Always add Notes in STATUS.md
   - Future you will thank you

---

## 🔄 Next Steps After Core Services

Once Phase 2A (Core) is complete:

1. **Review results:**
   - How many fixed vs removed?
   - Any patterns in issues found?

2. **Decide on Phase 2B:**
   - Continue with Feature Services (31)?
   - Or tackle Runtime Errors (9) first?

3. **Use quick_start.zsh again:**
   ```bash
   ./tools/launchagent_quick_start.zsh
   # Choose: 2 (Runtime First) or 3 (Full Sweep)
   ```

---

## 📝 Notes

- **Estimated time per service:** 5-10 minutes
- **Phase 2A total time:** 30-45 minutes (7 services)
- **Recommended pace:** 2-3 services per session (don't rush)

---

**Last Updated:** 2025-12-07  
**Status:** Ready to use

**See also:**
- `launchagent_repair_PHASE2_QUICK_CHECKLIST.md` - Quick reference checklist
- `launchagent_repair_PHASE2_EXAMPLE.md` - Complete walkthrough example (1 service)
