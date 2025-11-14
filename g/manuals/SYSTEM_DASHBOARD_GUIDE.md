# 02luka System Dashboard - User Guide

**Status:** ✅ OPERATIONAL
**URL:** http://127.0.0.1:8766
**Version:** 1.0

---

## 🎯 Overview

The 02luka System Dashboard provides real-time monitoring of all local agents, services, and work order execution progress in a beautiful HTML interface.

### Features

✅ **Real-time Service Monitoring**
- 41 total services tracked
- Live status updates (running/stopped/on-demand)
- PID and exit code information
- Color-coded status indicators

✅ **Work Order Progress Tracking**
- Visual progress bars for Phase 1 & 2
- Automatic detection of WO completion
- Real-time status updates

✅ **Activity Feed**
- Recent system events
- Service status changes
- Timestamped activity log

✅ **Live Log Viewer**
- Last 20 log lines
- Color-coded by severity (error/warn/info)
- Auto-refreshing

✅ **Auto-Refresh**
- Updates every 30 seconds
- Manual refresh button
- Last update timestamp

---

## 🚀 Quick Start

### Start Dashboard

```bash
~/02luka/tools/serve_dashboard.zsh
```

**Output:**
```
🚀 Starting 02luka System Dashboard...
   URL: http://127.0.0.1:8766

✅ Dashboard server started successfully
   PID: 56754

📊 Open dashboard:
   open http://127.0.0.1:8766
```

### Open in Browser

**Option 1: Auto-open**
```bash
open http://127.0.0.1:8766
```

**Option 2: Manual**
- Open browser
- Navigate to: `http://127.0.0.1:8766`

### Stop Dashboard

```bash
~/02luka/tools/serve_dashboard_stop.zsh
```

---

## 📊 Dashboard Sections

### 1. Status Cards (Top)

Four cards showing key metrics:

**Running Services** (Green)
- Services currently executing
- Have PID assigned
- Active processes

**OnDemand Services** (Blue)
- Services ready to run when triggered
- No active PID (waiting for events)
- Exit code: 0

**Stopped Services** (Orange)
- Services with errors
- Exit code > 0
- Require attention

**Total Services** (Gray)
- All registered services
- Total: 41 services

### 2. Active Services List

Real-time list of all services with:
- **Status Dot:** Color-coded indicator
  - 🟢 Green (pulsing): Running
  - 🔵 Blue: OnDemand (ready)
  - 🔴 Red: Error
  - ⚪ Gray: Stopped

- **Service Name:** Short name (without `com.02luka.`)
- **Status Badge:** Text status
- **PID:** Process ID (if running)
- **Exit Code:** Last exit status

**Example:**
```
🟢 autopilot          OnDemand   Exit: 0
🟢 expense.ocr        OnDemand   Exit: 0
🟢 telegram-bridge    Running    PID: 11594
```

### 3. Recent Activity Feed

Scrolling log of recent system events:
- Service status changes
- System refreshes
- Important events
- Timestamped entries

**Auto-managed:**
- Keeps last 20 events
- Newest at top
- Color-coded by type

### 4. Work Order Execution Progress

Two progress bars tracking WO execution:

**Phase 1: GD Sync Setup**
- Archives diagnostics
- Renames old GD folder
- Installs backup script
- Creates LaunchAgent
- Initial sync

**Phase 2: Two-Way Sync + Mobile Access**
- Conflict resolution system
- Two-way sync upgrade
- Mobile access docs
- Test sync

**Progress States:**
- 0%: Not started (gray)
- 1-99%: In progress (gradient animation)
- 100%: Complete (full color)

### 5. Live Logs

Terminal-style log viewer:
- Last 20 log lines
- Color-coded:
  - 🔴 Red: Errors
  - 🟡 Yellow: Warnings
  - 🔵 Blue: Info
  - 🟢 Green: Success

**Auto-scrolls** to show latest entries

---

## 🔧 Advanced Usage

### Custom Port

Start on different port:
```bash
~/02luka/tools/serve_dashboard.zsh 8080
```

Then access: `http://127.0.0.1:8080`

### API Access

Get raw JSON data:

```bash
# All services status
~/02luka/tools/dashboard_api.zsh services

# System stats
~/02luka/tools/dashboard_api.zsh stats

# WO progress
~/02luka/tools/dashboard_api.zsh wo-progress

# Recent logs
~/02luka/tools/dashboard_api.zsh logs

# Everything
~/02luka/tools/dashboard_api.zsh all
```

### Check Dashboard Status

```bash
# Check if running
ps aux | grep "http.server 8766"

# Or check PID file
cat ~/02luka/run/dashboard_http.pid
```

---

## 📱 Mobile Access

**Current:** Dashboard only accessible from local Mac (127.0.0.1)

**Future Options:**

1. **Cloudflare Tunnel** (Recommended)
   - Secure HTTPS access from anywhere
   - Already have tunnels set up
   - Can add dashboard endpoint

2. **Tailscale** (VPN)
   - Access via private VPN
   - Secure, no public exposure

3. **Google Drive Sync** (Snapshots)
   - Auto-export HTML snapshots to GD
   - View static snapshots on mobile
   - Updated every sync cycle

---

## 🎨 Understanding Status Indicators

### Status Dots

| Color | Meaning | Description |
|-------|---------|-------------|
| 🟢 Green (pulsing) | Running | Active process with PID |
| 🔵 Blue | OnDemand | Ready to run when triggered |
| 🔴 Red | Error | Exit code > 0, needs attention |
| ⚪ Gray | Stopped | Not running, exit code 0 |

### Status Badges

| Badge | Color | Meaning |
|-------|-------|---------|
| RUNNING | Green | Currently executing |
| ONDEMAND | Blue | Event-driven service (ready) |
| STOPPED | Gray | Not active |
| ERROR | Red | Failed with error code |

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Clean exit (normal) |
| >0 | Error exit (problem) |
| -15 | SIGTERM (normal shutdown) |

---

## 🛠️ Troubleshooting

### Dashboard Won't Start

**Error:** "Address already in use"
```bash
# Check what's using port 8766
lsof -i :8766

# Kill the process
kill <PID>

# Or use different port
~/02luka/tools/serve_dashboard.zsh 8767
```

### Dashboard Not Loading

**Check server:**
```bash
# Is it running?
ps aux | grep "http.server 8766"

# Check PID file
cat ~/02luka/run/dashboard_http.pid

# Restart
~/02luka/tools/serve_dashboard_stop.zsh
~/02luka/tools/serve_dashboard.zsh
```

### Data Not Updating

**Auto-refresh issues:**
- Dashboard refreshes every 30 seconds automatically
- Click "🔄 Refresh Now" button for immediate update
- Check browser console for errors (F12)

**Manual refresh:**
- Reload page: `Cmd+R` (Mac) or `Ctrl+R` (Windows)
- Hard reload: `Cmd+Shift+R` or `Ctrl+Shift+F5`

### Services Not Showing

**Check LaunchAgent status:**
```bash
# List all services
launchctl list | grep "com.02luka"

# Check specific service
launchctl list com.02luka.autopilot
```

---

## 📚 Related Documentation

- **Mobile Access:** `~/02luka/g/manuals/MOBILE_ACCESS_GUIDE.md`
- **Expense Tracker:** `~/02luka/EXPENSE_WEBUI_DEPLOYED.md`
- **GD Sync:** `~/02luka/GDRIVE_MOBILE_DEPLOYMENT_PLAN.md`

---

## 🔐 Security Notes

1. **Local Only:** Dashboard only accessible from 127.0.0.1 (your Mac)
2. **No Authentication:** Assumes single-user Mac environment
3. **Read-Only:** Dashboard displays status, cannot control services
4. **Safe to Run:** Simple HTTP server, no system modifications

**For external access:** Use Cloudflare Tunnel or VPN (don't expose directly)

---

## 🎓 Tips & Tricks

### Keep Dashboard Open

**Bookmark it:**
- `Cmd+D` in browser
- Save as: "02luka Dashboard"

**Auto-start on login:**
Create LaunchAgent (optional):
```bash
# Add to startup (future enhancement)
# Will be in next version
```

### Monitor Specific Service

**Watch autopilot:**
```bash
watch -n 2 'launchctl list com.02luka.autopilot'
```

**Watch expense OCR:**
```bash
tail -f ~/02luka/logs/expense_ocr*.log
```

### Dashboard + Terminal

**Split screen:**
- Left: Dashboard in browser
- Right: Terminal with log tail

**Example:**
```bash
# Terminal window
tail -f ~/02luka/logs/WO-251105-gdrive_fresh_start_hybrid.log
```

**Browser:** Dashboard showing progress bars

---

## 📊 What Services Mean

**Priority Services** (Most Important):

1. **autopilot** - Executes work orders (WOs)
2. **expense.ocr** - Processes receipts
3. **localtruth** - File system scanner
4. **backup.gdrive** - Google Drive sync

**Support Services:**

- **cloudflared.*** - Tunnels for remote access
- **gg.*** - GG assistant functions
- **telegram-bridge** - Telegram integration
- **watchdog*** - System health monitors

**OnDemand Services** (Triggered by events):

- **watch.*** - File watchers
- **autopilot.digest** - Daily summaries
- **alerts.*** - Notification systems

---

## 🚀 Future Enhancements

Planned features:

- [ ] Service control (start/stop from dashboard)
- [ ] Log search and filtering
- [ ] Historical charts (service uptime)
- [ ] Mobile-optimized view
- [ ] Cloudflare Pages deployment
- [ ] Slack/Telegram notifications
- [ ] Dark mode toggle
- [ ] Export reports (PDF/JSON)

---

## 📞 Quick Commands

```bash
# Start dashboard
~/02luka/tools/serve_dashboard.zsh

# Stop dashboard
~/02luka/tools/serve_dashboard_stop.zsh

# Get status data (JSON)
~/02luka/tools/dashboard_api.zsh all

# Check service
launchctl list com.02luka.autopilot

# View logs
tail -f ~/02luka/logs/*.log
```

---

**Created:** 2025-11-05
**Version:** 1.0
**Status:** Production Ready
**URL:** http://127.0.0.1:8766
