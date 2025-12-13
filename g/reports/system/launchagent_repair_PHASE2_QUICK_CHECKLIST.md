# Phase 2 Quick Checklist - Copy & Use
**Last Updated:** 2025-12-07

---

## ✅ Pre-Flight (2 min)

```bash
cd ~/02luka
git status  # Should be clean or known changes only

# Verify Phase 1 complete
launchctl list | grep "com.02luka" | awk '$2 == "127"' | wc -l
# Expected: 0

# Verify tools exist
test -f tools/launchagent_quick_start.zsh && echo "✅ Quick start ready"
test -f tools/launchagent_investigate_core.zsh && echo "✅ Investigation ready"
test -f g/reports/system/launchagent_repair_PHASE2_STATUS.md && echo "✅ Status tracker ready"
```

---

## 🚀 Start Phase 2 (Core Only - First Round)

```bash
cd ~/02luka
./tools/launchagent_quick_start.zsh
# Choose: 1 (Core Only)
```

**Read output completely** - all 7 services before proceeding.

---

## 📋 Per-Service Workflow (One-by-One)

### Step 1: Answer Questions (Mental Decision)

For each service, answer:
- **Q1:** Still needed? (Y/N/DEFER)
- **Q2:** If yes → Path/script/log ready? (Y/N)
- **Q3:** If no → REMOVE or ARCHIVE?

### Step 2: Execute Decision

#### FIX Pattern:
```bash
SERVICE="com.02luka.health_monitor"

# 1. Check current state
cat ~/Library/LaunchAgents/${SERVICE}.plist
launchctl list | grep "$SERVICE"

# 2. Fix paths (if old path found)
# Edit: ~/Library/LaunchAgents/${SERVICE}.plist
# Replace: /Users/icmini/LocalProjects/02luka_local_g
# With: /Users/icmini/02luka

# 3. Verify script exists and executable
SCRIPT_PATH=$(plutil -extract ProgramArguments.1 raw ~/Library/LaunchAgents/${SERVICE}.plist)
test -f "$SCRIPT_PATH" && chmod +x "$SCRIPT_PATH" || echo "⚠️ Script missing"

# 4. Reload service
launchctl bootout "gui/$(id -u)/$SERVICE" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" ~/Library/LaunchAgents/${SERVICE}.plist

# 5. Verify
launchctl list | grep "$SERVICE"
# Check exit code is 0 (not 78, 1, 2, 254)
```

#### REMOVE Pattern:
```bash
SERVICE="com.02luka.obsolete_service"
ARCHIVE_DIR="$HOME/02luka/_plists_archive_20251207"
mkdir -p "$ARCHIVE_DIR"

# 1. Unload
launchctl bootout "gui/$(id -u)/$SERVICE" 2>/dev/null || true

# 2. Archive plist (safer than delete)
mv ~/Library/LaunchAgents/${SERVICE}.plist "$ARCHIVE_DIR/" 2>/dev/null || true

# 3. Verify
launchctl list | grep "$SERVICE" || echo "✅ Removed"
ls "$ARCHIVE_DIR/${SERVICE}.plist" && echo "✅ Archived"
```

#### ARCHIVE Pattern (Same as REMOVE, but keep plist):
```bash
SERVICE="com.02luka.legacy_service"
ARCHIVE_DIR="$HOME/02luka/_plists_archive_20251207"
mkdir -p "$ARCHIVE_DIR"

launchctl bootout "gui/$(id -u)/$SERVICE" 2>/dev/null || true
mv ~/Library/LaunchAgents/${SERVICE}.plist "$ARCHIVE_DIR/"
ls "$ARCHIVE_DIR/${SERVICE}.plist" && echo "✅ Archived"
```

#### DEFER Pattern:
```bash
# No action - just update STATUS.md
# Mark as DEFER with note explaining why
```

### Step 3: Update STATUS.md

Edit: `g/reports/system/launchagent_repair_PHASE2_STATUS.md`

Change:
- Status: `PENDING` → `IN_PROGRESS` → `FIXED`/`REMOVED`/`ARCHIVED`/`DEFERRED`
- Decision: `FIX`/`REMOVE`/`ARCHIVE`/`DEFER`
- Notes: Brief explanation

### Step 4: Commit Progress (Every 1-3 services)

```bash
git add g/reports/system/launchagent_repair_PHASE2_STATUS.md
git add ~/Library/LaunchAgents/*.plist 2>/dev/null || true
git commit -m "fix(system): Phase 2A - <service> <decision>

- <brief note about what was done>
- Verified: launchctl list shows exit 0"
```

---

## ⚠️ Stop Rule

**If tired/confused → STOP**

Make sure STATUS.md is in a state where:
- You can read it later and know exactly where you left off
- Last service processed is marked `IN_PROGRESS` or `FIXED`/`REMOVED`/etc.

---

## 📊 Progress Check

After each session:
```bash
# Count remaining
grep -c "PENDING" g/reports/system/launchagent_repair_PHASE2_STATUS.md

# Count completed
grep -cE "(FIXED|REMOVED|ARCHIVED|DEFERRED)" g/reports/system/launchagent_repair_PHASE2_STATUS.md
```

---

**Next:** See `launchagent_repair_PHASE2_EXAMPLE.md` for full walkthrough of 1 service.
