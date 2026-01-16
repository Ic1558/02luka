# Cursor IDE Integration - Work Notes Automation

**Phase 4:** Automated digest refresh with Cursor/VSCode integration

---

## Overview

Enable automatic work notes digest refresh when opening the 02luka workspace in Cursor or VSCode.

**Benefits:**
- Digest auto-updates in the background
- No manual refresh needed
- Works seamlessly with IDE workflow

---

## Quick Setup (Recommended)

### 1. Create VSCode Tasks Configuration

Create or update `.vscode/tasks.json` in the repository root:

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Start Work Notes Watcher",
      "type": "shell",
      "command": "zsh",
      "args": ["g/tools/watch_work_notes.zsh"],
      "isBackground": true,
      "problemMatcher": [],
      "presentation": {
        "echo": true,
        "reveal": "silent",
        "focus": false,
        "panel": "dedicated",
        "showReuseMessage": false,
        "clear": false
      },
      "runOptions": {
        "runOn": "folderOpen"
      }
    }
  ]
}
```

### 2. Enable Auto-Run on Folder Open

**Cursor/VSCode Settings:**

Open settings (Cmd+, or Ctrl+,) and add:

```json
{
  "task.allowAutomaticTasks": "on"
}
```

Or via UI:
1. Open Command Palette (Cmd+Shift+P)
2. Search: "Preferences: Open Settings (JSON)"
3. Add: `"task.allowAutomaticTasks": "on"`

### 3. Verify Setup

1. **Close** and **reopen** the 02luka workspace
2. Check Terminal panel → should see "Starting work notes watcher..."
3. Test by writing a work note:
   ```bash
   python3 -c "from bridge.lac.writer import write_work_note; write_work_note('test', 'CURSOR-TEST', 'testing cursor integration', 'success')"
   ```
4. Verify digest updates automatically:
   ```bash
   tail -n 1 g/core_state/work_notes_digest.jsonl
   ```

---

## Alternative Setup (Manual Start)

If you prefer manual control, skip auto-run and start the watcher manually:

### Via Command Palette

1. Open Command Palette (Cmd+Shift+P)
2. Search: "Tasks: Run Task"
3. Select: "Start Work Notes Watcher"

### Via Keyboard Shortcut

Add to `.vscode/keybindings.json`:

```json
[
  {
    "key": "cmd+shift+w",
    "command": "workbench.action.tasks.runTask",
    "args": "Start Work Notes Watcher"
  }
]
```

---

## Advanced Configuration

### Custom Digest Line Count

Edit the task in `.vscode/tasks.json`:

```json
{
  "label": "Start Work Notes Watcher",
  "type": "shell",
  "command": "DIGEST_LINES=500 zsh g/tools/watch_work_notes.zsh",
  ...
}
```

### Multiple Workspace Setup

If you work with multiple 02luka clones, create workspace-specific tasks:

```json
{
  "label": "Start Work Notes Watcher (Main)",
  "command": "cd ~/02luka && zsh g/tools/watch_work_notes.zsh"
},
{
  "label": "Start Work Notes Watcher (Dev)",
  "command": "cd ~/02luka_dev && zsh g/tools/watch_work_notes.zsh"
}
```

---

## Troubleshooting

### Watcher Not Starting

**Check task auto-run setting:**
```bash
# In VSCode settings, ensure:
"task.allowAutomaticTasks": "on"
```

**Check terminal output:**
- Open Terminal panel (Cmd+`)
- Look for "Starting work notes watcher..." message
- If missing, try "Tasks: Restart Running Task"

### fswatch Not Found

**Install fswatch:**
```bash
# macOS
brew install fswatch

# Linux (Ubuntu/Debian)
sudo apt-get install fswatch

# Linux (Fedora)
sudo dnf install fswatch
```

**Watcher will fallback to polling mode if fswatch unavailable**

### High CPU Usage

Watcher should use <0.1% CPU when idle. If high:

1. Check for infinite loop in watcher script
2. Verify journal isn't being modified rapidly
3. Try polling mode (remove fswatch temporarily)

### Digest Not Updating

**Check watcher is running:**
```bash
ps aux | grep watch_work_notes
```

**Verify digest tool works manually:**
```bash
python3 g/tools/update_work_notes_digest.py --lines 200
```

**Check journal exists:**
```bash
ls -lh g/core_state/work_notes.jsonl
```

---

## Stop the Watcher

### From VSCode

1. Open Terminal panel
2. Click trash icon next to "Task - Start Work Notes Watcher"

### From Command Line

```bash
pkill -f watch_work_notes
```

---

## Performance Impact

**Expected resource usage:**
- CPU (idle): <0.1%
- CPU (on change): 1-5% for <1 second
- Memory: ~10 MB
- Disk I/O: Minimal (only on journal changes)

**Benchmark on M1 Mac:**
- fswatch mode: 0.0% CPU idle, <100ms update latency
- Polling mode: 0.1% CPU idle, <5s update latency

---

## Integration with Other IDEs

### VSCodium / Code - OSS

Same setup as VSCode (uses identical tasks.json format)

### JetBrains IDEs (PyCharm, IntelliJ)

Use "External Tools" feature:

1. Preferences → Tools → External Tools
2. Add new tool:
   - Name: Start Work Notes Watcher
   - Program: zsh
   - Arguments: g/tools/watch_work_notes.zsh
   - Working directory: $ProjectFileDir$

### Vim / Neovim

Add to your init.vim / init.lua:

```vim
" Start watcher on VimEnter
autocmd VimEnter * silent !zsh g/tools/watch_work_notes.zsh &
```

### Emacs

Add to your .emacs or init.el:

```elisp
(defun start-work-notes-watcher ()
  (interactive)
  (start-process "work-notes-watcher" nil "zsh" "g/tools/watch_work_notes.zsh"))

(add-hook 'after-init-hook 'start-work-notes-watcher)
```

---

## FAQ

**Q: Do I need to restart the watcher after each commit?**
A: No, watcher monitors the journal file itself, not git state.

**Q: Does this work with remote development (SSH)?**
A: Yes, but watcher must run on the remote machine. Configure task with remote shell.

**Q: Can multiple watchers run simultaneously?**
A: Yes, but not recommended. Each watcher will trigger digest updates independently (wasteful but harmless).

**Q: What happens if watcher crashes?**
A: System continues working. Cron fallback (every 5min) ensures digest stays fresh. Post-write hooks also provide redundancy.

---

## Related Documentation

- [Core State Bus](CORE_STATE_BUS.md) - Overall architecture
- [Cron Setup](../cron/README.md) - Fallback automation
- [Deep Analysis](../reports/DEEP_ANALYSIS_WORK_NOTES_DATA_LOSS.md) - Original problem analysis

---

**Last Updated:** 2026-01-16 (Phase 4)
**Maintainer:** CLC
