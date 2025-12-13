# Phase 2 Ultra-Short Cheat Sheet
**5-Line Reference** - Print & Keep on Desk

---

## 🚀 Quick Start (5 Steps)

```
1. cd ~/02luka && ./tools/launchagent_quick_start.zsh → Choose 1 (Core Only)
2. For each service: Answer Q1-Q3 → Decide: FIX/REMOVE/ARCHIVE/DEFER
3. Execute: FIX → plutil + chmod +x + reload | REMOVE/ARCHIVE → bootout + mv to archive
4. Update: g/reports/system/launchagent_repair_PHASE2_STATUS.md (PENDING → FIXED/REMOVED/etc)
5. Commit: git add STATUS.md + plist && git commit -m "fix(system): Phase 2A - <service> <decision>"
```

---

## 📋 Decision Matrix

| Question | Answer | Action |
|----------|--------|--------|
| Q1: Still needed? | Y | → Q2: Path ready? |
| Q1: Still needed? | N | → Q3: REMOVE or ARCHIVE? |
| Q1: Still needed? | DEFER | → Mark DEFER in STATUS, skip action |
| Q2: Path ready? | Y | → FIX (update plist + reload) |
| Q2: Path ready? | N | → FIX (update plist + reload) |
| Q3: REMOVE/ARCHIVE? | REMOVE | → bootout + mv to archive |
| Q3: REMOVE/ARCHIVE? | ARCHIVE | → bootout + mv to archive |

---

## 🔧 One-Liner Patterns

**FIX:**
```bash
SERVICE="<name>"; plutil -replace ProgramArguments.1 -string "/Users/icmini/02luka/tools/<script>" ~/Library/LaunchAgents/${SERVICE}.plist && chmod +x /Users/icmini/02luka/tools/<script> && launchctl bootout "gui/$(id -u)/$SERVICE" 2>/dev/null; launchctl bootstrap "gui/$(id -u)" ~/Library/LaunchAgents/${SERVICE}.plist && launchctl list | grep "$SERVICE"
```

**REMOVE/ARCHIVE:**
```bash
SERVICE="<name>"; ARCHIVE_DIR="$HOME/02luka/_plists_archive_20251207"; mkdir -p "$ARCHIVE_DIR" && launchctl bootout "gui/$(id -u)/$SERVICE" 2>/dev/null && mv ~/Library/LaunchAgents/${SERVICE}.plist "$ARCHIVE_DIR/" && echo "✅ Archived"
```

---

## 📊 STATUS Update Template

```markdown
| `com.02luka.<service>` | ✅ FIXED | FIX | <brief note> |
| `com.02luka.<service>` | ✅ REMOVED | REMOVE | <brief note> |
| `com.02luka.<service>` | ✅ ARCHIVED | ARCHIVE | <brief note> |
| `com.02luka.<service>` | ⏸️ DEFERRED | DEFER | <reason> |
```

---

## ⚠️ Stop Rule

**If tired/confused → STOP**

Make sure STATUS.md shows last service as `IN_PROGRESS` or `FIXED`/`REMOVED`/etc.

---

**Full Guides:**
- `launchagent_repair_PHASE2_QUICK_CHECKLIST.md` - Detailed checklist
- `launchagent_repair_PHASE2_EXAMPLE.md` - Complete walkthrough
- `launchagent_repair_PHASE2_SAFE_START.md` - Full guide
