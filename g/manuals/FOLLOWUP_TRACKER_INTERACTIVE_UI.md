# Follow-Up Tracker - Interactive UI Manual

**Version:** 1.0
**Deployed:** 2025-11-06
**Status:** ✅ PRODUCTION READY
**Location:** http://127.0.0.1:8766/followup.html

---

## Overview

The Follow-Up Tracker is a real-time, interactive web dashboard for managing follow-up tasks, reminders, and dependencies. It features live JSON auto-updates every 5 minutes, smart UI interactions, task dependencies, and modal-based detail views.

## Features

### 1. Live Auto-Updating Data
- **Auto-refresh:** Every 30 seconds (web UI) + every 5 minutes (JSON data via LaunchAgent)
- **Real-time status detection:** Dashboard API, MLS format validation, RAG federation, GitHub PRs
- **Single source of truth:** `~/02luka/g/knowledge/followup_index.json`

### 2. Interactive Task Management

#### Task States
- **Pending:** Green indicator, clickable, shows action buttons
- **Blocked:** Red indicator, reduced opacity, not clickable, shows tooltip with blocking reason
- **Completed:** Green checkmark, read-only, no actions

#### Task Actions
Each pending task shows two action buttons:
- **View:** Opens detailed modal with full information
- **✓ Complete:** Quick completion with confirmation dialog

### 3. Modal Detail View

Click any pending task to open a modal with:
- **Status badge:** Visual indicator of task state
- **Details section:** Parent item, handler, estimated time
- **Blocked By section:** Shows tasks blocking this one (if applicable)
- **This Task Blocks section:** Shows dependent tasks (if applicable)
- **Related Report section:** Link to report URL (if available)

#### Modal Actions
- **✓ Mark as Completed:** Changes task status, unblocks dependent tasks
- **📄 View Report:** Opens related report in new tab
- **📋 Copy Details:** Copies task info to clipboard
- **Close:** ESC key or click overlay to dismiss

### 4. Smart UI Interactions

#### Hover Effects
- **Pending tasks:** Highlight + slide animation on hover
- **Blocked tasks:** No hover effect (disabled state)
- **Tooltips:** Show blocking information on hover

#### Visual Feedback
- **Cursor changes:** Pointer for clickable, not-allowed for blocked
- **Opacity:** Blocked tasks at 60% opacity
- **Color coding:**
  - P1 (Priority 1): Red badges
  - P2 (Priority 2): Orange badges
  - P3 (Priority 3): Green badges

### 5. Dependency Tracking

Tasks can have relationships:
- **`blocked_by`:** Array of task IDs blocking this task
- **`blocks`:** Array of task IDs this task blocks

When a task is marked complete:
1. Task status changes to `completed`
2. Dependent tasks are automatically unblocked
3. Dashboard refreshes to reflect changes

## URLs

### Main Dashboard
```
http://127.0.0.1:8766/followup.html
```
Shows all active and completed follow-up items.

### Filtered View (MLS Failures)
```
http://127.0.0.1:8766/followup.html?scope=mls&mls=failures
```
Shows only MLS-related failure items.

### JSON API
```
http://127.0.0.1:8766/data/followup.json
```
Direct access to live JSON data (auto-updated every 5 minutes).

## Quick Access Paths

All paths point to the same file via symlinks:

```bash
# CLI quick access
~/02luka/followup.json

# Dashboard integration
~/02luka/g/apps/dashboard/data/followup.json

# Tools access
~/02luka/tools/data/followup.json

# Runtime directory
~/02luka/g/run/followup_index.json

# Primary source
~/02luka/g/knowledge/followup_index.json
```

## JSON Structure

### Active Item Example
```json
{
  "id": "FOLLOWUP-001",
  "priority": 1,
  "title": "Dashboard API + MLS Data Fixes",
  "status": "delegated",
  "handler": "local_agents",
  "date_added": "2025-11-06T05:45:00+07:00",
  "report_url": "http://127.0.0.1:8766/reports/PHASE_14_1_FEDERATION.md",
  "tasks": [
    {
      "task_id": "1.1",
      "description": "Fix Dashboard API port 8770 conflict",
      "status": "pending",
      "estimated_minutes": 15,
      "blocking": false
    },
    {
      "task_id": "1.2",
      "description": "Fix MLS JSONL format",
      "status": "pending",
      "estimated_minutes": 15,
      "blocking": true,
      "blocks": ["1.3"]
    },
    {
      "task_id": "1.3",
      "description": "Re-run RAG federation",
      "status": "blocked",
      "estimated_minutes": 5,
      "blocked_by": ["1.2"]
    }
  ]
}
```

### Metadata Example
```json
{
  "metadata": {
    "last_updated": "2025-11-06T05:27:01+0700",
    "total_active": 2,
    "total_completed": 1,
    "total_tasks_pending": 4,
    "total_tasks_blocked": 1
  }
}
```

## Interactive Features Reference

### JavaScript Functions

#### Core Functions
- `loadFollowup()` - Fetches and renders data from JSON API
- `renderActiveItems(items)` - Renders active items with interactive elements
- `renderCompletedItems(items)` - Renders completed items (read-only)

#### Modal Functions
- `showTaskDetails(itemId, taskId)` - Opens modal with task details
- `closeModal()` - Closes modal (also triggered by ESC key or overlay click)
- `markTaskCompleted()` - Marks current task as completed
- `quickMarkComplete(itemId, taskId)` - Quick completion without modal

#### Utility Functions
- `viewReport()` - Opens related report in new tab
- `copyTaskDetails()` - Copies task info to clipboard

### Event Handlers

#### Keyboard Shortcuts
- **ESC:** Close modal

#### Mouse Interactions
- **Click task:** Open detail modal (pending tasks only)
- **Click overlay:** Close modal
- **Hover blocked task:** Show tooltip with blocking reason

## Color Scheme

### Priority Badges
- **P1:** `#f56565` (Red) - Highest priority
- **P2:** `#ed8936` (Orange) - Medium priority
- **P3:** `#48bb78` (Green) - Lower priority

### Status Badges
- **Delegated:** `#fbd38d` (Yellow/Orange)
- **Pending:** `#fc8181` (Light Red)
- **In Progress:** `#63b3ed` (Blue)
- **Completed:** `#68d391` (Green)

### Task Status Indicators
- **Pending:** `#fed7d7` (Light Red circle)
- **Blocked:** `#feb2b2` (Dark Red circle)
- **Completed:** `#9ae6b4` (Green circle)

## Technical Implementation

### Tech Stack
- **Frontend:** Vanilla JavaScript (no frameworks)
- **Styling:** Pure CSS with flexbox and gradients
- **Data:** JSON API with fetch()
- **Auto-update:** LaunchAgent + shell script

### Key Files

| File | Purpose |
|------|---------|
| `g/apps/dashboard/followup.html` | Main interactive UI |
| `g/knowledge/followup_index.json` | Live JSON data source |
| `tools/followup_tracker_update.zsh` | Auto-update script |
| `Library/LaunchAgents/com.02luka.followup_tracker.plist` | Background service |
| `logs/followup_tracker.log` | Update logs |

### Browser Compatibility
- **Tested:** Chrome, Safari, Firefox (latest versions)
- **Requirements:** ES6+ support, Fetch API, Clipboard API
- **Mobile:** Responsive design with touch support

## Usage Examples

### Example 1: View Task Details
1. Open http://127.0.0.1:8766/followup.html
2. Find pending task in active items
3. Click task row or click "View" button
4. Modal opens with full details
5. Click "Close" or press ESC to dismiss

### Example 2: Mark Task Completed
**Quick Method:**
1. Click "✓ Complete" button on task
2. Confirm in dialog
3. Dashboard refreshes automatically

**Modal Method:**
1. Click task to open modal
2. Review details
3. Click "✓ Mark as Completed"
4. Modal closes, dashboard refreshes

### Example 3: Copy Task Details
1. Open task detail modal
2. Click "📋 Copy Details"
3. Success notification appears
4. Paste into any application:
```
Task: 1.1
Description: Fix Dashboard API port 8770 conflict
Status: pending
Parent: Dashboard API + MLS Data Fixes
Handler: local_agents
Estimated Time: ~15 minutes
```

### Example 4: View Related Report
1. Open task detail modal
2. Check if "📄 View Report" button is visible
3. Click button to open report in new tab
4. Report opens at configured URL

## Troubleshooting

### Task Not Clickable
**Possible reasons:**
- Task status is `blocked` → Check tooltip for blocking tasks
- Task status is `completed` → Completed tasks are read-only
- JavaScript error → Check browser console (F12)

**Fix:**
- Complete blocking tasks first
- Refresh page (F5)
- Check console for errors

### Modal Not Opening
**Possible reasons:**
- Data not loaded yet → Wait for "Loading..." to disappear
- Task is blocked or completed
- Browser console errors

**Fix:**
```bash
# Check if JSON is accessible
curl http://127.0.0.1:8766/data/followup.json

# Check browser console
# Open DevTools (F12) → Console tab → Look for errors
```

### Auto-Refresh Not Working
**Check LaunchAgent status:**
```bash
launchctl list | grep followup_tracker
# Should show PID (e.g., 57407)

# Check logs
tail -f ~/02luka/logs/followup_tracker.log
```

**Restart service:**
```bash
launchctl unload ~/Library/LaunchAgents/com.02luka.followup_tracker.plist
launchctl load ~/Library/LaunchAgents/com.02luka.followup_tracker.plist
```

### JSON Not Updating
**Manual update:**
```bash
~/02luka/tools/followup_tracker_update.zsh
```

**Check primary source:**
```bash
cat ~/02luka/g/knowledge/followup_index.json | jq '.metadata.last_updated'
```

## Adding New Follow-Up Items

### Step 1: Edit JSON
```bash
# Open primary source
nano ~/02luka/g/knowledge/followup_index.json
```

### Step 2: Add Item
```json
{
  "id": "FOLLOWUP-003",
  "priority": 2,
  "title": "New Follow-Up Task",
  "status": "pending",
  "handler": "clc",
  "date_added": "2025-11-06T10:00:00+07:00",
  "report_url": "http://127.0.0.1:8766/reports/TASK_REPORT.md",
  "tasks": [
    {
      "task_id": "3.1",
      "description": "First subtask",
      "status": "pending",
      "estimated_minutes": 30
    }
  ]
}
```

### Step 3: Validate
```bash
# Check JSON syntax
jq . ~/02luka/g/knowledge/followup_index.json

# If valid, refresh dashboard
# Opens automatically at http://127.0.0.1:8766/followup.html
```

## Best Practices

### Task Descriptions
✅ **Good:** "Fix Dashboard API port 8770 conflict"
❌ **Bad:** "Fix API"

✅ **Good:** "Re-run RAG federation after MLS format fix"
❌ **Bad:** "Run federation"

### Priority Levels
- **P1:** Critical, blocking other work
- **P2:** Important, should be done soon
- **P3:** Nice to have, can wait

### Task Dependencies
- Use `blocked_by` to explicitly declare dependencies
- Use `blocks` to show what this task enables
- Avoid circular dependencies

### Estimated Time
- Be realistic (15-30 min increments)
- Include testing and verification time
- Pad for unexpected issues

## Keyboard Shortcuts Summary

| Key | Action |
|-----|--------|
| ESC | Close modal |
| F5 | Refresh dashboard |
| F12 | Open browser DevTools |

## API Integration (Future)

The current implementation uses client-side alerts for completion actions. In production, this would integrate with a backend API:

```javascript
// Future implementation example
async function markTaskCompleted() {
  const response = await fetch('/api/tasks/complete', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      item_id: currentItemId,
      task_id: currentTask.task_id
    })
  });

  if (response.ok) {
    closeModal();
    loadFollowup(); // Refresh data
  }
}
```

## Related Documentation

- **Quick Reference:** `g/manuals/FOLLOWUP_TRACKER_QUICK_REF.md`
- **Symlink Map:** `g/reports/FOLLOWUP_TRACKER_SYMLINK_MAP.md`
- **Cursor Fix Report:** `g/reports/CURSOR_GIT_FIX_20251106.md`

---

**Status:** ✅ PRODUCTION READY
**Version:** 1.0
**Last Updated:** 2025-11-06
**Maintained By:** CLC
