# Follow-Up Tracker System - Quick Reference

**Status:** ✅ PRODUCTION READY
**Version:** v1.0
**Deployed:** 2025-11-06
**Auto-updates:** Every 5 minutes

## Live JSON Tracking

**Primary Location:** `~/02luka/g/knowledge/followup_index.json`

**Quick Access Symlinks:**
- `~/02luka/followup.json` (root level - fastest)
- `~/02luka/g/apps/dashboard/data/followup.json` (dashboard integration)
- `~/02luka/tools/data/followup.json` (tools access)
- `~/02luka/g/run/followup_index.json` (runtime directory)

**Features:**
- ✅ Real-time auto-updates every 5 minutes
- ✅ Detects system status automatically
- ✅ Dashboard-ready JSON format
- ✅ Task dependency tracking
- ✅ Completion history

## Quick Commands

```bash
# View current status (use ANY of these paths)
cat ~/02luka/followup.json | jq .
cat ~/02luka/g/knowledge/followup_index.json | jq .

# View active items only
jq '.active_items' ~/02luka/g/knowledge/followup_index.json

# View metadata (last update, counts)
jq '.metadata' ~/02luka/g/knowledge/followup_index.json

# Manual update
~/02luka/tools/followup_tracker_update.zsh

# Check LaunchAgent status
launchctl list | grep followup_tracker

# View update logs
tail -f ~/02luka/logs/followup_tracker.log
```

## Auto-Detection

The system automatically detects:

1. **Dashboard API** - Checks port 8770 status
2. **MLS Format** - Validates JSONL format
3. **RAG Federation** - Counts mls:// entries in database
4. **GitHub PRs** - Counts open pull requests

## JSON Structure

```json
{
  "active_items": [
    {
      "id": "FOLLOWUP-001",
      "priority": 1,
      "title": "...",
      "status": "delegated|pending|in_progress",
      "handler": "local_agents|clc|gg",
      "tasks": [
        {
          "task_id": "1.1",
          "description": "...",
          "status": "pending|completed|blocked",
          "blocked_by": ["1.2"]  // Task dependencies
        }
      ]
    }
  ],
  "completed_items": [...],
  "metadata": {
    "last_updated": "2025-11-06T05:27:01+0700",
    "total_active": 2,
    "total_tasks_pending": 4
  }
}
```

## Dashboard Integration

### Web UI (Port 8766)
✅ **Main View:** http://127.0.0.1:8766/followup.html
- Real-time auto-refresh (30 seconds)
- Color-coded status badges
- Task breakdown with progress
- Mobile-responsive design

✅ **MLS Failures Filter:** http://127.0.0.1:8766/followup.html?scope=mls&mls=failures
- Shows only MLS-related failures
- Quick access for specific scope filtering

✅ **JSON API:** http://127.0.0.1:8766/data/followup.json
- Raw JSON for programmatic access
- Updates every 5 minutes via LaunchAgent

The JSON file can also be consumed by:
- Dashboard API (port 8770)
- CLI tools
- Monitoring systems

## Files

| File | Purpose |
|------|---------|
| `g/knowledge/followup_index.json` | Live JSON data (PRIMARY SOURCE) |
| `followup.json` | Root-level symlink (quick access) |
| `g/apps/dashboard/data/followup.json` | Dashboard symlink |
| `tools/data/followup.json` | Tools symlink |
| `g/run/followup_index.json` | Runtime symlink |
| `tools/followup_tracker_update.zsh` | Update script |
| `Library/LaunchAgents/com.02luka.followup_tracker.plist` | Auto-update service |
| `logs/followup_tracker.log` | Update logs |

## Service Management

```bash
# Stop updates
launchctl unload ~/Library/LaunchAgents/com.02luka.followup_tracker.plist

# Start updates
launchctl load ~/Library/LaunchAgents/com.02luka.followup_tracker.plist

# Restart service
launchctl unload ~/Library/LaunchAgents/com.02luka.followup_tracker.plist
launchctl load ~/Library/LaunchAgents/com.02luka.followup_tracker.plist
```

## Adding New Tasks

Edit `followup_index.json` to add new active items:

```json
{
  "id": "FOLLOWUP-003",
  "priority": 3,
  "title": "New Task Title",
  "status": "pending",
  "handler": "clc",
  "date_added": "2025-11-06T...",
  "tasks": [...]
}
```

Then run manual update to validate:
```bash
~/02luka/tools/followup_tracker_update.zsh
```

## Current Active Items

1. **Priority 1:** Dashboard API + MLS Data (delegated to local agents)
2. **Priority 2:** GitHub PR Cleanup (pending for CLC)

---

**Auto-updates:** Every 5 minutes
**Last manual update:** 2025-11-06T05:27:01+0700
**Status:** ✅ OPERATIONAL
