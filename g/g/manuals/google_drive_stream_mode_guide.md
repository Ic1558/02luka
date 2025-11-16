# Google Drive Stream Mode Guide
**Created:** 2025-11-04
**Status:** Active (STREAM mode confirmed)

## Current Configuration

### Mount Point
- **Primary:** `~/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/`
- **My Drive Access:** Via symlink at mount point (virtual files)
- **Cache Location:** `~/Library/Application Support/Google/DriveFS/` (1.5GB)
- **Active Files:** 2,921 files in .tmp sync folder

### Stream Mode Benefits
✅ **Minimal Local Storage** - Files downloaded on-demand
✅ **Always Up-to-Date** - Changes sync automatically
✅ **60GB+ Free Space** - Compared to Mirror mode
✅ **Stable Operation** - No sync conflicts

## Accessing Files

### Correct Path
```bash
cd ~/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My\ Drive/02luka/
```

### Environment Variable (Recommended)
```bash
export LUKA_GD_ROOT="$HOME/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive"
export LUKA_GD_BASE="$LUKA_GD_ROOT/02luka"
```

## Making Folders Available Offline

For folders you need frequent access to:

1. **Via Finder:**
   - Navigate to the folder in Finder
   - Right-click the folder
   - Select "Offline access" → "Available offline"

2. **Via Google Drive Menu Bar:**
   - Click Google Drive icon in menu bar
   - Click ⚙️ Settings → Preferences
   - Go to "Google Drive" tab
   - Under "Offline," manage folders

3. **Recommended for 02luka:**
   - Keep Stream mode as default
   - Only mark specific high-use folders offline
   - Target: <20GB total cached data

## Folder Structure

```
~/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/
├── My Drive/                    (symlink to virtual location)
│   ├── 02luka/                  (your primary GD folder)
│   ├── [other folders]
├── Other computers/             (linked computers)
├── .tmp/                        (2,921 sync files)
└── .shortcut-targets-by-id/     (shared drive shortcuts)
```

## Troubleshooting

### If Finder Sidebar Missing
1. Open Finder Preferences (Cmd+,)
2. Go to "Sidebar" tab
3. Check "Google Drive" under "Locations"

### If Files Not Accessible
```bash
# Check Google Drive status
ps aux | grep "Google Drive" | grep -v grep

# Restart Google Drive
osascript -e 'quit app "Google Drive"'
open -a "Google Drive"
```

### If Cache Too Large
```bash
# Check current cache size
du -sh ~/Library/Application\ Support/Google/DriveFS/

# Clear cache (will re-download on access)
# ⚠️ Only if needed:
# killall "Google Drive"
# rm -rf ~/Library/Application\ Support/Google/DriveFS/content_cache/
# open -a "Google Drive"
```

## System Integration

### Current Environment (.zshrc)
```bash
# Google Drive (Stream Mode)
export LUKA_GD_ROOT="${LUKA_GD_ROOT:-$HOME/Library/CloudStorage/*/My Drive}"
export LUKA_GD_BASE="${LUKA_GD_BASE:-$LUKA_GD_ROOT/02luka}"
```

### Aliases
```bash
# Quick navigation (defined in .zshrc)
alias gd="cd \"$HOME/02luka\""  # Local SOT (primary)
```

## Best Practices

1. **Prefer Local SOT** - Use `/Users/icmini/02luka/` for active work
2. **GD for Backup** - Use Google Drive for backup/sync only
3. **Selective Offline** - Only cache frequently-accessed folders
4. **Monitor Space** - Keep <150GB total disk usage
5. **Stream First** - Always use Stream mode unless specific need

## Health Checks

```bash
# Verify mount exists
test -d ~/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com && echo "✓ Mounted"

# Check process running
pgrep -f "Google Drive" && echo "✓ Running"

# Check cache size
du -sh ~/Library/Application\ Support/Google/DriveFS/

# Count active sync files
ls ~/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/.tmp/ 2>/dev/null | wc -l
```

## Notes

- **Broken Symlink Normal:** The "My Drive" symlink at the mount point appears broken to `test -d` but works for file operations
- **Virtual Files:** Files in Stream mode don't have physical presence until accessed
- **Cache is Normal:** 1.5GB cache is expected for metadata and recently accessed files
- **No Mirror Needed:** Current disk space (130GB free) sufficient with Stream mode

---

**Last Verified:** 2025-11-04
**Mode:** STREAM ✅
**Status:** Healthy ✅
