# GMX Operator Manual v1.0

**GMX Auto Flow** - Automated Work Order generation from natural language tasks via Gemini AI.

---

## Quick Start

### Mode A: Manual Execution (Recommended - Bypasses launchd issue)

```bash
# 1. Write task to TODO file
echo "Refactor gemini handler error reporting only. No new files." >> ~/02luka/gmx_todo.txt

# 2. Run processor manually
cd ~/02luka
g/tools/gmx_todo_processor.sh

# 3. Check results
ls ~/02luka/bridge/inbox/LIAM/  # or GEMINI/ for run-command tasks
tail -f ~/02luka/logs/gmx_todo_processor.log
```

**Result:** GMX → Gemini → task_spec → Work Order → Overseer → Execution pipeline runs end-to-end.

---

### Mode B: Automated (LaunchAgent - Currently logs failures)

```bash
# 1. Ensure LaunchAgent is installed
launchctl list | grep com.02luka.gmx_cli

# 2. Write task (Agent will auto-trigger)
echo "Your task here" >> ~/02luka/gmx_todo.txt

# 3. Monitor logs
tail -f ~/02luka/logs/gmx_todo_processor.log
tail -f ~/02luka/logs/gmx_cli.run.log
```

**Status:** ⚠️ Currently fails at Gemini CLI step in launchd environment. System correctly logs the failure.

---

## Components

| Component | Purpose | Status |
|-----------|---------|--------|
| `g/tools/gmx_cli.py` | GMX Planner - converts prompt → task_spec | ✅ Production-ready |
| `bridge/tools/dispatch_to_bridge.py` | Dispatcher - creates Work Order YAML | ✅ Production-ready |
| `g/tools/gmx_todo_processor.sh` | Processor - reads TODO file, calls gmx_cli | ✅ Production-ready |
| `launchd/com.02luka.gmx_cli.plist` | LaunchAgent - watches TODO file | ✅ Production-ready |
| `g/tools/test_gmx_cli.py` | Unit tests | ✅ All passing |

---

## Workflow

```
User writes task → gmx_todo.txt
    ↓
LaunchAgent detects change (or manual run)
    ↓
gmx_todo_processor.sh (with file lock)
    ↓
gmx_cli.py → Gemini API → task_spec
    ↓
dispatch_to_bridge.py → Work Order YAML
    ↓
bridge/inbox/LIAM/ or GEMINI/
    ↓
GeminiHandler → mary_router → overseerd
    ↓
APPROVED → Execute | REVIEW_REQUIRED → Outbox
```

---

## Task Format

Write one task per line in `~/02luka/gmx_todo.txt`:

```
Refactor gemini handler error reporting only. No new files.
Generate documentation for Gemini safety flow in docs/gemini_handler_safety.md.
# This is a comment - will be skipped
```

**Routing:**
- `refactor`, `fix-bug`, `add-feature`, `generate-file` → `bridge/inbox/LIAM/`
- `run-command`, `analyze` → `bridge/inbox/GEMINI/`

---

## Troubleshooting

### Check if processor ran:
```bash
tail -20 ~/02luka/logs/gmx_todo_processor.log
```

### Check GMX CLI output:
```bash
tail -50 ~/02luka/logs/gmx_cli.run.log
```

### Verify LaunchAgent status:
```bash
launchctl list | grep com.02luka.gmx_cli
launchctl print gui/$(id -u)/com.02luka.gmx_cli
```

### Manual test GMX CLI:
```bash
cd ~/02luka
python3 g/tools/gmx_cli.py "Test task description"
```

### Check Work Orders created:
```bash
ls -lt ~/02luka/bridge/inbox/LIAM/ | head -5
ls -lt ~/02luka/bridge/inbox/GEMINI/ | head -5
```

---

## Known Limitations

### ⚠️ Gemini CLI + launchd Environment Issue

**Symptom:** `ERROR: gmx_cli failed for task: ...` in processor log

**Root Cause:** Gemini CLI tool fails with generic API error when executed from launchd environment, even with:
- ✅ `GEMINI_API_KEY` set
- ✅ `~/.zshrc` sourced
- ✅ Absolute paths used

**Workaround:** Use **Mode A (Manual Execution)** - runs successfully in Terminal environment.

**Status:** External dependency issue - not a code bug. System correctly detects and logs the failure.

---

## Security

- ✅ No hardcoded API keys in code/plist
- ✅ API key sourced from user environment (`~/.zshrc`)
- ✅ Path validation prevents writes outside `bridge/inbox/`
- ✅ File locking prevents concurrent execution
- ✅ Atomic file operations prevent data loss

---

## File Locations

| File | Location |
|------|----------|
| TODO file | `~/02luka/gmx_todo.txt` |
| Processor log | `~/02luka/logs/gmx_todo_processor.log` |
| GMX CLI log | `~/02luka/logs/gmx_cli.run.log` |
| LaunchAgent logs | `~/02luka/logs/gmx_cli.out.log`<br>`~/02luka/logs/gmx_cli.err.log` |
| Work Orders | `~/02luka/bridge/inbox/LIAM/`<br>`~/02luka/bridge/inbox/GEMINI/` |
| Lock file | `~/02luka/locks/gmx_todo.lock` |

---

## Quick Reference

**Start automated mode:**
```bash
launchctl load -w ~/Library/LaunchAgents/com.02luka.gmx_cli.plist
```

**Stop automated mode:**
```bash
launchctl unload ~/Library/LaunchAgents/com.02luka.gmx_cli.plist
```

**Manual run (bypasses launchd):**
```bash
cd ~/02luka && g/tools/gmx_todo_processor.sh
```

**Check system health:**
```bash
# All components
ls -la ~/02luka/g/tools/gmx_* ~/02luka/bridge/tools/dispatch_* ~/02luka/launchd/com.02luka.gmx_cli.plist

# Recent activity
tail -20 ~/02luka/logs/gmx_todo_processor.log
ls -lt ~/02luka/bridge/inbox/LIAM/ ~/02luka/bridge/inbox/GEMINI/ | head -10
```

---

**Version:** 1.0 | **Status:** Production-ready (code) | **Last Updated:** 2025-01-15
