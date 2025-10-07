# Auto-Start Configuration - Hybrid Setup ✅

**Timestamp:** 2025-10-06T03:02:00Z
**Strategy:** Hybrid (MCP FS auto, Task Bus manual)

---

## 🎯 Configuration Summary

**Auto-Start (Always On):**
- ✅ MCP FS Server (port 8765)
  - Starts on login
  - Restarts if crashes
  - Cursor always has MCP access

**Manual Start (On Demand):**
- ⏸️ Task Bus Bridge
  - Start when coordinating multiple agents
  - Lightweight, low overhead

---

## ✅ MCP FS Server (Auto-Start)

### LaunchAgent Details
**File:** `~/Library/LaunchAgents/com.02luka.mcp.fs.plist`
**Source:** `g/fixed_launchagents/com.02luka.mcp.fs.plist`
**Status:** ✅ Loaded and running

**Configuration:**
```xml
<key>Label</key>
<string>com.02luka.mcp.fs</string>

<key>RunAtLoad</key>
<true/>

<key>KeepAlive</key>
<true/>

<key>ThrottleInterval</key>
<integer>10</integer>
```

### Process Info
- **PID:** 35719
- **Port:** 8765
- **Transport:** SSE
- **Endpoint:** `http://127.0.0.1:8765/sse`
- **Root:** `$FS_ROOT` (02luka SOT path)

### Logs
- **stdout:** `/tmp/mcp_fs_py.out`
- **stderr:** `/tmp/mcp_fs_py.err`

### Control Commands
```bash
# Check status
launchctl print gui/$UID/com.02luka.mcp.fs

# View logs
tail -f /tmp/mcp_fs_py.out

# Restart
launchctl kickstart -k gui/$UID/com.02luka.mcp.fs

# Stop
launchctl bootout gui/$UID/com.02luka.mcp.fs

# Start
launchctl bootstrap gui/$UID ~/Library/LaunchAgents/com.02luka.mcp.fs.plist
```

---

## ⏸️ Task Bus Bridge (Manual)

### Start When Needed
```bash
# Option 1: Use control script
bash g/tools/task_bus_control.sh start

# Option 2: Manual start
cd ~/dev/02luka-repo
REDIS_URL='redis://:changeme-02luka@127.0.0.1:6379/0' \
python3 g/bridge/task_bus_bridge.py \
  >> ~/Library/Logs/02luka/task_bus_bridge.out 2>&1 &
```

### Stop
```bash
# Option 1: Use control script
bash g/tools/task_bus_control.sh stop

# Option 2: Manual stop
pkill -f "task_bus_bridge.py"
```

### Check Status
```bash
bash g/tools/task_bus_control.sh status
```

### When to Use
**Start the bridge when:**
- Working with multiple AI agents (CLC + Cursor + Codex)
- Need real-time task coordination
- Want to track cross-agent task history

**You can skip the bridge when:**
- Only using Cursor (MCP FS is enough)
- Working solo without coordination needs
- Doing simple tasks

---

## 🔄 What Auto-Starts on Login

**Immediately after login:**
```
✅ MCP FS Server launches automatically
   → Cursor can use MCP tools right away
   → No manual intervention needed
```

**Task Bus Bridge:**
```
⏸️ Does NOT auto-start (by design)
   → Start manually when coordinating agents
   → Saves resources when not needed
```

---

## 🎯 Cursor Integration

### Always Available (via MCP FS)
Cursor can always use these MCP tools:
- `read_text(relpath)` - Read files from SOT
- `list_dir(relpath)` - List directory contents
- `file_info(relpath)` - Get file metadata

### Example Usage in Cursor
```
"Read a/memory/active_tasks.json"
"List files in g/tools"
"Show me the contents of 02luka.md"
```

---

## 📊 Current Status

**Verification Results:**

| Component | Status | Auto-Start | PID |
|-----------|--------|------------|-----|
| MCP FS Server | ✅ Running | YES | 35719 |
| Task Bus Bridge | ✅ Running | NO | 29664 |
| Redis Backend | ✅ Running | External | Docker |

**Health Check:**
```bash
# MCP FS
curl -N http://127.0.0.1:8765/sse
# Response: SSE stream (timeout expected) ✅

# Task Bus (if running)
ps aux | grep task_bus_bridge.py
```

---

## 🔧 Troubleshooting

### MCP FS Not Starting

**Check LaunchAgent status:**
```bash
launchctl print gui/$UID/com.02luka.mcp.fs
```

**Check logs:**
```bash
tail -50 /tmp/mcp_fs_py.err
```

**Common issues:**
1. **Python venv missing:** Install with `python3 -m venv ~/.venv/mcpfs`
2. **Port 8765 in use:** Kill process using `lsof -ti tcp:8765 | xargs kill`
3. **FS_ROOT path wrong:** Check path in plist matches actual SOT location

**Fix and reload:**
```bash
# Edit plist if needed
vi ~/Library/LaunchAgents/com.02luka.mcp.fs.plist

# Reload
launchctl bootout gui/$UID/com.02luka.mcp.fs
launchctl bootstrap gui/$UID ~/Library/LaunchAgents/com.02luka.mcp.fs.plist
```

### Cursor Can't See MCP Tools

**1. Check server is running:**
```bash
ps aux | grep mcp_fs_server.py
```

**2. Check Cursor MCP config:**
```bash
cat .cursor/mcp.example.json
# Should have: "mcp_fs": {"transport": "sse", "url": "http://127.0.0.1:8765/sse"}
```

**3. Reload Cursor:**
```
Cmd+Shift+P → "Reload Window"
```

**4. Check Cursor Settings:**
```
Settings → Tools & MCP
Should see: ✅ mcp_fs (green indicator)
```

---

## 🎁 Benefits of Hybrid Setup

**Auto MCP FS:**
- ✅ Zero maintenance - just works
- ✅ Cursor always ready to use MCP tools
- ✅ Survives reboots automatically
- ✅ Restarts on crash (KeepAlive)

**Manual Task Bus:**
- ✅ Resources saved when not needed
- ✅ Start only when coordinating agents
- ✅ No background noise in logs
- ✅ Full control over when it runs

---

## 📝 Quick Reference

### Daily Use

**Morning:**
```bash
# Nothing to do! MCP FS auto-started ✅
# Open Cursor and start working
```

**When coordinating with multiple agents:**
```bash
# Start task bus
bash g/tools/task_bus_control.sh start

# Publish events
bash g/tools/emit_task_event.sh clc my_task started "context"

# Stop when done (optional)
bash g/tools/task_bus_control.sh stop
```

---

## 🔄 Migration Notes

**Previous Setup:**
- Manual start for both MCP FS and Task Bus

**Current Setup:**
- ✅ MCP FS: LaunchAgent (auto-start)
- ⏸️ Task Bus: Manual start (on demand)

**Benefits:**
- Cursor works immediately after login
- No manual intervention for basic MCP functionality
- Coordinated multi-agent work when needed

---

## ✅ Verification

**Test auto-start:**
1. Restart Mac
2. Login
3. Wait 5 seconds
4. Run: `ps aux | grep mcp_fs_server.py`
5. Should see process running ✅
6. Open Cursor
7. Ask: "Read 02luka.md"
8. Should work immediately ✅

**Test manual coordination:**
1. Start task bus: `bash g/tools/task_bus_control.sh start`
2. Publish event: `bash g/tools/emit_task_event.sh clc test started`
3. Check in Cursor: "Read a/memory/active_tasks.json"
4. Should see event ✅

---

**Configuration deployed:** 2025-10-06T03:02:00Z
**Strategy:** Hybrid auto-start (Option 3)
**Status:** ✅ Production Ready
