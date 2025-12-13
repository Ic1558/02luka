# Phase 2C-Mini: Quick Reference

**Target:** 3 Orchestrator Services (Exit 2)  
**Date:** 2025-12-07

---

## 1. Pre-Flight (2 minutes)

```bash
cd ~/02luka
git status  # Check current diffs

# Verify 3 services still in list
launchctl list | egrep "mary-coo|delegation-watchdog|clc-executor" || echo "⚠️ none listed"

# Verify toolkit exists
ls g/reports/system/launchagent_repair_PHASE2C_MINI_*.md
```

---

## 2. Service Investigation Pattern

```bash
SERVICE="com.02luka.mary-coo"  # Change for each service
PLIST="$HOME/Library/LaunchAgents/${SERVICE}.plist"
LOG="$HOME/02luka/logs/${SERVICE}.log"

# 1) Read plist
cat "$PLIST"
SCRIPT_PATH=$(plutil -extract ProgramArguments.1 raw "$PLIST" 2>/dev/null || plutil -extract ProgramArguments.0 raw "$PLIST" 2>/dev/null)
echo "Script: $SCRIPT_PATH"
test -f "$SCRIPT_PATH" || echo "⚠️ script missing"

# 2) Check log
tail -40 "$LOG" 2>/dev/null || echo "⚠️ no log"

# 3) Manual run (see actual error)
"$SCRIPT_PATH" 2>&1 | tail -40
```

**Decision Questions:**
- Still needed? → **YES** (all 3 are core orchestrators)
- Root cause? → Check log/manual run
- Decision? → **FIX** (not REMOVE/ARCHIVE)

---

## 3. Fix & Reload

```bash
SERVICE="com.02luka.mary-coo"  # Change for each
PLIST="$HOME/Library/LaunchAgents/${SERVICE}.plist"

# Fix paths/env (based on log findings)
# ... edit plist using plutil -replace ...

# Reload
launchctl bootout "gui/$(id -u)/$SERVICE" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"

# Verify
launchctl list | grep "$SERVICE"
tail -10 "$HOME/02luka/logs/${SERVICE}.log"
```

---

## 4. Update STATUS.md

Edit `g/reports/system/launchagent_repair_PHASE2_STATUS.md`:

```markdown
| `com.02luka.mary-coo` | ✅ FIXED | FIX | Root cause: <summary> |
```

**Notes format:**
- `fixed PYTHONPATH`
- `updated venv path`
- `updated redis URL`
- `fixed script permissions`

---

## 5. Commit (Every 1-3 services)

```bash
cd ~/02luka
git add g/reports/system/launchagent_repair_PHASE2_STATUS.md
git add ~/Library/LaunchAgents/com.02luka.mary-coo.plist 2>/dev/null || true
git add ~/Library/LaunchAgents/com.02luka.delegation-watchdog.plist 2>/dev/null || true
git add ~/Library/LaunchAgents/com.02luka.clc-executor.plist 2>/dev/null || true

git commit -m "fix(system): Phase 2C-mini - orchestrator lane

- Fixed mary-coo (root cause: <summary>)
- Fixed delegation-watchdog (root cause: <summary>)
- Fixed clc-executor (root cause: <summary>)"
```

---

## Services Order

1. **mary-coo** (delegation orchestrator)
2. **delegation-watchdog** (monitors stuck tasks)
3. **clc-executor** (WO execution)

---

**Reference:**
- Detailed walkthrough: `launchagent_repair_PHASE2C_MINI_EXAMPLE.md`
- Expected behavior: `launchagent_repair_PHASE2C_MINI_EXPECTED_BEHAVIOR.md`
