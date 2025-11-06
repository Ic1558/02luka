# Cursor AI (CLS) Setup & Integration

**Created**: 2025-11-06
**Status**: ✅ Production Ready

## Overview

This document explains the Cursor workspace setup, Cursor AI (CLS) chat history management, and integration with Claude Code (CLC).

## Problem Solved

**Issue**: Cursor kept opening in wrong mode:
- Initially: Opened "02luka-dual (Workspace)" instead of simple folder
- Root cause: Devcontainer auto-reconnect from `.devcontainer/devcontainer.json`

**Solution**:
1. Disabled `.devcontainer/` folder → `.devcontainer.disabled`
2. Created launcher script with `--disable-workspace-trust` flag
3. Protected workspace storage containing chat history

## Current Setup

### Launcher Script

**Location**: `~/bin/cursor-02luka`

```bash
# Launch Cursor correctly
cursor       # alias
c            # short alias
~/bin/cursor-02luka  # direct path
```

**What it does**:
1. Kills existing Cursor processes
2. Opens `~/02luka` as single folder (not workspace)
3. Uses `--disable-workspace-trust` to prevent devcontainer auto-open
4. Preserves workspace storage (contains chat history)

### Workspace Storage Location

**Path**: `~/Library/Application Support/Cursor/User/workspaceStorage/`

**Contains**:
- `state.vscdb` - SQLite database with chat history
- `composer.composerData` - Cursor AI conversations
- Code indexing and context
- Extension data

**⚠️ CRITICAL**: Do NOT delete this directory! Chat history is stored here.

## CLC <> CLS Connection

### What is What?

- **CLC** (Claude Code): Me, the AI assistant in your terminal/Claude app
- **CLS** (Cursor AI): The AI assistant in Cursor IDE Composer panel

### How They Work Together

1. **CLC** (This session):
   - Runs in terminal or Claude app
   - Has access to file system and commands
   - Can read/write code, run scripts, manage system
   - Session history managed by Claude Code

2. **CLS** (Cursor Composer):
   - Runs inside Cursor IDE
   - Has access to codebase context and files
   - Chat history stored in `workspaceStorage/*/state.vscdb`
   - Persistent across Cursor restarts (as long as workspace storage isn't deleted)

### Connection Status

✅ **Both Working Independently**:
- CLC: ✅ Active (this session)
- CLS: ✅ Will persist chat history going forward
- Workspace: ✅ Opens correctly (no container/dual workspace)

❌ **What's Lost**:
- Old CLS chat history from before 2025-11-06 20:00 (accidentally deleted during troubleshooting)

✅ **What's Protected Now**:
- Future CLS chat history will persist correctly
- Launcher script documented to never clear workspace storage
- Setup is stable and won't break on Cursor restart

## Common Operations

### Start Cursor (Correct Way)
```bash
cursor
# or
c
```

### Check Chat History Location
```bash
ls -la ~/Library/Application\ Support/Cursor/User/workspaceStorage/
```

### Backup Chat History
```bash
# Before making system changes
BACKUP_DIR=~/02luka/_cursor_backup_$(date +%Y%m%d_%H%M)
mkdir -p "$BACKUP_DIR"
rsync -a ~/Library/Application\ Support/Cursor/User/workspaceStorage/ "$BACKUP_DIR/"
```

### Restore Chat History (if needed)
```bash
# From backup
rsync -a ~/02luka/_cursor_backup_YYYYMMDD_HHMM/ ~/Library/Application\ Support/Cursor/User/workspaceStorage/
```

## Troubleshooting

### Cursor Opens in Container Mode
- Check: `.devcontainer` folder should be disabled (`.devcontainer.disabled`)
- Fix: `mv ~/02luka/.devcontainer ~/02luka/.devcontainer.disabled`

### Cursor Opens Dual Workspace
- Check: No `*-dual.code-workspace` files should exist
- Fix: Rename to `*.disabled`

### Chat History Not Loading
- Check workspace storage exists: `ls ~/Library/Application\ Support/Cursor/User/workspaceStorage/`
- Check database size: Should be > 1KB if you have chat history
- Restore from backup if accidentally deleted

### Launcher Not Working
```bash
# Verify script exists
ls -la ~/bin/cursor-02luka

# Check permissions
chmod +x ~/bin/cursor-02luka

# Verify aliases
grep "cursor" ~/.zshrc
source ~/.zshrc
```

## Architecture

```
User runs: cursor
    ↓
~/bin/cursor-02luka
    ↓
[Kill existing Cursor]
    ↓
[Launch Cursor]
    ├── Target: ~/02luka (single folder)
    ├── Flag: --disable-workspace-trust (prevents devcontainer)
    └── Flag: --new-window
    ↓
Cursor opens correctly
    ├── Title: "02luka" (not CONTAINER)
    ├── Workspace Storage: Preserved
    └── CLS Chat History: Available
```

## Files Reference

| File | Purpose | Status |
|------|---------|--------|
| `~/bin/cursor-02luka` | Launcher script | ✅ Active |
| `~/.zshrc` | Aliases (`cursor`, `c`) | ✅ Active |
| `~/02luka/.devcontainer.disabled` | Disabled devcontainer | ✅ Disabled |
| `~/02luka/*-dual.code-workspace.disabled` | Disabled dual workspace | ✅ Disabled |
| `~/Library/Application Support/Cursor/User/workspaceStorage/` | Chat history storage | ✅ Protected |

## Lessons Learned

1. **Always backup before clearing cache** - We lost old chat history by clearing workspace storage
2. **Workspace storage ≠ just cache** - It contains user data (chat history)
3. **Devcontainer auto-open can be prevented** - Use `--disable-workspace-trust` flag
4. **Document critical paths** - Chat history location now documented in launcher script

## Next Steps (Optional)

### Automated Backups
```bash
# Add to crontab for daily backups
0 3 * * * rsync -a ~/Library/Application\ Support/Cursor/User/workspaceStorage/ ~/02luka/_cursor_backups/$(date +\%Y\%m\%d)/ 2>/dev/null
```

### Monitoring
```bash
# Check workspace storage size (should grow over time)
du -sh ~/Library/Application\ Support/Cursor/User/workspaceStorage/
```

---

**Related**:
- [Phase 14 System Restoration](../reports/PHASE_14_FINAL_SYSTEM_RESTORATION.md)
- [02luka System Manual](../../02luka.md)

**Co-Authored-By**: Claude <noreply@anthropic.com>
