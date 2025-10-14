# Stream Mode Setup - Complete
**Date:** 2025-10-03 02:04:00
**Status:** ✅ Phase 1 Complete (User action required for Phase 2)

## Summary

Successfully prepared system for Google Drive Stream Mode migration with clean symlink paths.

## Phase 1: Preparation (COMPLETE ✅)

### 1. Pre-Migration Snapshot
```
✅ Snapshot: /run/snapshots/pre_stream_migration_20251003
✅ Purpose: Rollback safety if Stream mode causes issues
✅ Contents: All LaunchAgent states, port configs, system state
```

### 2. Clean Symlink Path
```bash
✅ Created: ~/dev/02luka-repo
✅ Target: /Users/icmini/My Drive (ittipong.c@gmail.com) (1)/02luka
✅ Benefit: No spaces, no escaping, clean paths
```

### 3. Shell Environment Updated
**Added to `~/.zshrc`:**
```bash
# 02luka Stream Mode Setup (2025-10-03)
export SOT_PATH="$HOME/dev/02luka-repo"
alias 02l='cd "$SOT_PATH"'
```

**Usage:**
```bash
# Quick navigation
02l  # Goes to ~/dev/02luka-repo

# Scripts can use
cd "$SOT_PATH"  # Clean, no spaces
```

## Phase 2: Stream Mode Switch (USER ACTION REQUIRED)

### Manual Steps:

1. **Switch Google Drive to Stream Mode:**
   - Open Google Drive app
   - Preferences → Settings
   - Change from "Mirror files" to "Stream files"
   - Click "Quit" and restart Google Drive

2. **Mark Critical Paths for Offline:**
   - Right-click → "Available offline":
     - ✅ `02luka/` (entire folder)
     - ✅ `02luka-repo/` if separate
     - ✅ `CLC/`
     - ✅ `g/tools/`

3. **Wait for Initial Sync:**
   - May take 5-10 minutes
   - Files download on first access
   - Check: Files show cloud icon → download icon → checkmark

### Verification Commands:
```bash
# Test symlink works
cd ~/dev/02luka-repo && pwd

# Test scripts accessible
ls -lh g/tools/verify_system.sh

# Check Google Drive status
ls -lah "$HOME/My Drive (ittipong.c@gmail.com) (1)/02luka" | head -10
```

## Phase 3: Validation (After Stream Switch)

### Run These Commands:
```bash
# Set SOT_PATH for session
export SOT_PATH="$HOME/dev/02luka-repo"

# Or reload shell config
source ~/.zshrc

# Navigate to repo
02l  # or: cd "$SOT_PATH"

# Run preflight (creates snapshots)
bash 02luka-repo/.codex/preflight.sh

# Validate mappings
bash g/tools/mapping_drift_guard.sh --validate

# Optional: Push to GitHub
AUTO_PUSH=1 bash 02luka-repo/.codex/preflight.sh
```

### Light Smoke Test:
```bash
# Test without heavy services
02l
API_PORT=4001 UI_PORT=5173 bash run/smoke_api_ui.sh --light
```

## Benefits of Stream Mode

### Storage Savings:
- **Before (Mirror):** All files downloaded (~10-50GB)
- **After (Stream):** Only accessed files downloaded
- **Preload Critical:** 02luka-repo, CLC, g/tools (~1-2GB)

### Performance:
- ✅ Faster deploys (no sync lag)
- ✅ Lighter Cursor/VSCode (less file watching)
- ✅ On-demand loading (access when needed)

### Clean Paths:
- ✅ No more escaping: `~/dev/02luka-repo`
- ✅ Works in all shells: bash, zsh, scripts
- ✅ Tab completion: `cd ~/dev/02<TAB>`

## Troubleshooting

### Symlink Not Working:
```bash
# Check symlink
ls -lh ~/dev/02luka-repo

# Re-create if needed
rm ~/dev/02luka-repo
ln -s "/Users/icmini/My Drive (ittipong.c@gmail.com) (1)/02luka" ~/dev/02luka-repo
```

### Scripts Not Found After Stream Switch:
```bash
# Mark folder offline
# Right-click folder → "Available offline"

# Or force download
cd ~/dev/02luka-repo
find . -maxdepth 3 -type f -print0 | xargs -0 -n50 cat >/dev/null 2>/dev/null
```

### Stream Mode Issues:
```bash
# Rollback to Mirror Mode
# Google Drive → Preferences → "Mirror files"

# Restore from snapshot if needed
cp -r /Users/icmini/My\ Drive\ \(ittipong.c@gmail.com\)\ \(1\)/02luka/run/snapshots/pre_stream_migration_20251003/* .
```

### LaunchAgents Failing:
```bash
# Check if paths still work
launchctl list | grep 02luka

# Reload if needed
launchctl bootout gui/$(id -u)/com.02luka.fastvlm
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.02luka.fastvlm.plist
```

## Status Checklist

- [x] Pre-migration snapshot created
- [x] Symlink ~/dev/02luka-repo created
- [x] Shell environment updated (~/.zshrc)
- [x] Path validation passed
- [ ] **USER: Switch to Stream Mode**
- [ ] **USER: Mark critical paths offline**
- [ ] Run preflight.sh validation
- [ ] Run mapping_drift_guard.sh
- [ ] Execute light smoke test
- [ ] Verify LaunchAgents still work

## Next Steps

**USER ACTION REQUIRED:**

1. Switch Google Drive to Stream Mode (see Phase 2 above)
2. Mark `02luka/` for offline access
3. Wait for initial sync
4. Run validation commands (Phase 3)
5. Report any issues

**After Stream Mode Active:**
```bash
# Quick validation
02l && bash 02luka-repo/.codex/preflight.sh
```

---

*Setup by: CLC*
*Date: 2025-10-03*
*Location: `/g/reports/STREAM_MODE_SETUP_20251003.md`*
