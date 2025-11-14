# Mobile Access Guide - 02luka System

**Last Updated:** $(date '+%Y-%m-%d')

## 🎯 Quick Start

You can now **edit files from mobile** and they will sync back to your Mac automatically.

### What Works

✅ **Read & Write:** All 8 synced directories
✅ **Mobile → Mac:** Changes sync automatically every 4 hours
✅ **Mac → Mobile:** Changes sync automatically every 4 hours
✅ **Conflict Resolution:** Automatic (keeps newer version)

### Synced Directories

```
~/gd/02luka_sync/current/
├── g/              # Apps, reports, inbox (includes expense tracker)
├── CLC/            # Work orders
├── manuals/        # Documentation
├── docs/           # System docs
├── scripts/        # Automation scripts
├── agents/         # AI agents
├── bridge/         # Integration bridges
└── tools/          # Utilities
```

## 📱 Mobile Editing Workflow

### Expense Tracker (Most Common Use Case)

**Path on Google Drive:**
```
02luka_sync/current/g/apps/expense/
```

**Files you can edit:**
- `ledger_2025.jsonl` - Add new expense entries
- `payees.json` - Add new payees
- `projects.json` - Add new projects
- `index.html` - Edit UI (advanced)

**Example: Add expense from mobile**

1. Open Google Drive app
2. Navigate to: `02luka_sync/current/g/apps/expense/`
3. Edit `ledger_2025.jsonl`
4. Add new line:
   ```json
   {"id":"EXP-1730800000","date":"2025-11-05","payee":"Coffee Shop","project":"PRJ-DIP110","category":"Meals","amount":4.50,"currency":"THB","vat":0.32,"note":"Team meeting","attachment":""}
   ```
5. Save file
6. Changes sync to Mac within 4 hours
7. Mac syncs back to GD within 4 hours

**Total sync time:** Up to 8 hours (4h + 4h)
**Speed it up:** Run manual sync on Mac

### Manual Sync (Mac)

Force immediate sync:
```bash
~/02luka/tools/backup_to_gdrive.zsh
```

This runs:
1. Pull from GD → Mac (get mobile edits)
2. Check for conflicts
3. Push from Mac → GD (send Mac edits)

## 🔧 Advanced Usage

### Edit Other Files

**Add new work order from mobile:**
```
02luka_sync/current/bridge/inbox/
→ Create new .json file with work order
→ CLC picks it up on next scan
```

**Update documentation:**
```
02luka_sync/current/docs/
→ Edit any .md file
→ Syncs to Mac automatically
```

**Modify scripts:**
```
02luka_sync/current/tools/
→ Edit .zsh or .sh files
→ Test on Mac after sync
```

## ⚠️ Conflict Handling

**What is a conflict?**
- Same file edited on mobile AND Mac before sync
- Example: Edit `ledger.jsonl` on mobile at 2pm, Mac at 3pm, sync at 4pm

**Auto-resolution:**
- System keeps **newer version** (by timestamp)
- Both versions saved to: `~/02luka/g/reports/sync_conflicts_<timestamp>/`
- Files tagged: `*.LOCAL` (Mac version), `*.REMOTE` (mobile version)

**Manual resolution:**
```bash
# Check for conflicts
~/02luka/tools/resolve_gdrive_conflicts.zsh

# Review conflicted files
ls ~/02luka/g/reports/sync_conflicts_*/

# Compare versions
diff file.LOCAL file.REMOTE

# Choose which to keep (already auto-resolved, but you can override)
```

## 📊 Monitoring Sync

**Check last sync:**
```bash
tail -20 ~/02luka/logs/backup_to_gdrive_run.log
```

**Watch live sync:**
```bash
tail -f ~/02luka/logs/backup_to_gdrive_run.log
```

**Verify sync status:**
```bash
# On Mac
ls -lt ~/02luka/g/apps/expense/

# Compare to GD
ls -lt ~/gd/02luka_sync/current/g/apps/expense/
```

## 🚀 Best Practices

### DO ✅
- Edit small text files (JSON, MD, TXT, CSV)
- Wait 10+ hours between edits to same file (avoids conflicts)
- Use expense tracker for receipts on the go
- Add work orders from mobile
- Update documentation from mobile

### DON'T ❌
- Edit large files (>10MB) on mobile (slow sync)
- Edit binary files (images, PDFs) unless necessary
- Edit same file on mobile and Mac within 8 hours
- Delete directories (only edit/add files)

### Tips
- **Best time to edit on mobile:** Right after Mac sync (0 conflicts)
- **Check sync schedule:** Every 4 hours (00:00, 04:00, 08:00, 12:00, 16:00, 20:00)
- **Need urgent sync:** SSH to Mac and run manual sync
- **Large changes:** Do them on Mac (faster, safer)

## 🔐 Security Notes

**Google Drive Access:**
- Files encrypted in transit (HTTPS)
- Access via Google account only
- Enable 2FA on Google account

**Sensitive Data:**
- Don't store passwords/keys in synced files
- Use `~/.env` or `~/.ssh/` (not synced)
- Expense receipts: OK (business data)

## 📞 Troubleshooting

### Sync Not Working

**Check LaunchAgent:**
```bash
launchctl list | grep gdrive
```

**Restart sync service:**
```bash
launchctl unload ~/Library/LaunchAgents/com.02luka.sync.gdrive.4h.plist
launchctl load -w ~/Library/LaunchAgents/com.02luka.sync.gdrive.4h.plist
```

### File Not Appearing

**Check sync logs:**
```bash
grep "filename" ~/02luka/logs/backup_to_gdrive_run.log
```

**Verify file location:**
```bash
find ~/gd/02luka_sync -name "filename"
```

### Conflicts Keep Happening

**Solution 1:** Increase sync frequency (reduce 4h to 1h)
**Solution 2:** Use file locking (edit on mobile OR Mac, not both)
**Solution 3:** Separate work areas (mobile edits g/inbox/, Mac edits elsewhere)

## 🎓 Example Workflows

### Workflow 1: Receipt Entry on Mobile
```
1. Take photo of receipt → Google Drive Photos
2. Open GD: 02luka_sync/current/g/apps/expense/ledger_2025.jsonl
3. Add new entry with receipt photo link
4. Save file
5. (Wait 4h or SSH to Mac and run manual sync)
6. Open expense tracker UI on Mac: http://127.0.0.1:8765
7. Verify entry appears
```

### Workflow 2: Create Work Order from Mobile
```
1. Open GD: 02luka_sync/current/bridge/inbox/
2. Create new file: WO-TASK-<timestamp>-description.json
3. Add work order JSON:
   {
     "task": "Review expense report",
     "priority": "normal",
     "timestamp": 1730800000
   }
4. Save file
5. (Wait 4h for sync)
6. CLC picks up work order automatically
```

### Workflow 3: Update Documentation
```
1. Open GD: 02luka_sync/current/docs/
2. Edit any .md file
3. Make changes
4. Save
5. (Wait 4h for sync)
6. Changes appear in local SOT
7. Git commit if needed
```

---

**System Status:** ✅ Two-Way Sync Enabled
**Sync Interval:** Every 4 hours
**Conflict Resolution:** Automatic (keeps newer)
**Mobile Access:** Full read/write via Google Drive
