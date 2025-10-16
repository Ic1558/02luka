# 🔍 02LUKA System Verification Guide

**Purpose:** Quick commands to verify what's actually running
**Use When:** You need to double-check system state
**Last Updated:** 2025-10-17

---

## ✅ Quick Health Check (30 seconds)

```bash
# 1. Check critical services
lsof -i :4000 -i :5173 -i :8765 2>/dev/null | grep LISTEN

# Expected output:
# Python   XXXX ... TCP localhost:ultraseek-http (LISTEN)  ← Port 4000: MCP FS Server
# node     XXXX ... TCP localhost:terabase (LISTEN)        ← Port 8765: Boss API
# Python   XXXX ... TCP localhost:5173 (LISTEN)            ← Port 5173: UI Server

# 2. Check GitHub workflows
gh workflow list | head -5

# Expected: 10 active workflows including "OPS Monitoring"

# 3. Check LaunchAgents
launchctl list | grep -i 02luka | wc -l

# Expected: ~36 LaunchAgents running

# 4. Check git status
cd ~/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My\ Drive/02luka/02luka-repo
git status

# Expected: "On branch main, Your branch is up to date with 'origin/main'"
```

---

## 🏗️ Current System Architecture

### **Services Running (as of 2025-10-17)**

| Port | Service | Process | Purpose |
|------|---------|---------|---------|
| 4000 | MCP FS Server | `mcp_fs_server.py` | File system MCP access |
| 8765 | Boss API | `node server.cjs` | API server for UI/integrations |
| 5173 | UI Server | `python -m http.server` | Static file server |

**Verify Command:**
```bash
lsof -i :4000 -i :5173 -i :8765 2>/dev/null | grep LISTEN
```

### **GitHub Actions Workflows (10 Active)**

| Workflow | Status | ID | Purpose |
|----------|--------|-----|---------|
| OPS Monitoring | ✅ Active | 198478238 | Automated OPS checks every 6h |
| CI | ✅ Active | 196280991 | Continuous integration |
| Auto Update PR branches | ✅ Active | 198220096 | Keep PRs up to date |
| Deploy Dashboard | ✅ Active | 197068137 | Dashboard deployment |
| Daily Proof (Option C) | ✅ Active | 196446425 | Daily proof generation |
| Deploy to GitHub Pages | ✅ Active | 191875988 | GitHub Pages publishing |

**Verify Command:**
```bash
gh workflow list
gh run list --workflow "OPS Monitoring" --limit 3
```

**Latest OPS Monitoring Run:**
- Status: ✅ completed, success
- Duration: 1m41s
- Executed: 2025-10-16T18:36:39Z (scheduled run)

### **LaunchAgents Automation (36 Active)**

```bash
# List all 02luka LaunchAgents
launchctl list | grep -i 02luka

# Check specific agent status
launchctl list | grep com.02luka.sot.render
launchctl list | grep com.02luka.mcp.fs
```

**Key LaunchAgents:**
- `com.02luka.sot.render` - SOT rendering every 12h
- `com.02luka.mcp.fs` - MCP FS server auto-start
- (34 more automation agents)

---

## 📊 System Pipeline (Current State)

```
┌─────────────────────────────────────────────────────────────────┐
│                    ENTRY POINTS                                 │
├─────────────────────────────────────────────────────────────────┤
│ 1. Claude Code → MCP FS Server (port 4000)                     │
│ 2. Web UI → Boss API (port 8765) → UI Server (port 5173)       │
│ 3. GitHub Actions → Scheduled workflows (OPS Monitoring, etc)  │
│ 4. LaunchAgents → 36 automated background tasks                │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│              PROCESSING LAYER                                   │
├─────────────────────────────────────────────────────────────────┤
│ • MCP FS Server → File system operations                       │
│ • Boss API → API endpoints, health checks                      │
│ • ops_atomic.sh → 5-phase testing (smoke, verify, report)      │
│ • reportbot → Generate OPS_SUMMARY.json                        │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    OUTPUT LAYER                                 │
├─────────────────────────────────────────────────────────────────┤
│ • GitHub Actions artifacts → OPS reports (30-day retention)     │
│ • g/reports/ → Local report storage                            │
│ • Discord notifications → Optional webhook alerts               │
│ • GitHub Pages → Public dashboard publishing                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔧 Detailed Verification Commands

### **1. Verify Repository State**
```bash
cd ~/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My\ Drive/02luka/02luka-repo

# Check branch and sync status
git status
git log --oneline -5

# Check for uncommitted changes
git diff
git diff --staged

# Verify remote connection
git remote -v
```

**Expected Output:**
- Branch: main
- Status: "Your branch is up to date with 'origin/main'"
- Remote: git@github.com:Ic1558/02luka.git

### **2. Verify Services Running**
```bash
# Check all 02luka processes
ps aux | grep -E "(mcp_fs_server|server.cjs|http.server)" | grep -v grep

# Check ports in use
lsof -i :4000 -i :5173 -i :8765

# Test service endpoints
curl -s http://127.0.0.1:4000/health || echo "MCP FS Server not responding"
curl -s http://127.0.0.1:8765/healthz || echo "Boss API not responding"
curl -s http://127.0.0.1:5173/ > /dev/null && echo "UI Server responding" || echo "UI Server not responding"
```

### **3. Verify GitHub Actions**
```bash
# List all workflows
gh workflow list

# Check recent runs
gh run list --limit 10

# Check specific workflow
gh run list --workflow "OPS Monitoring" --limit 3

# View latest run details
gh run view --log
```

**Expected Workflows:**
- OPS Monitoring (scheduled every 6h)
- CI (on push/PR)
- Auto Update PR branches (on main push)
- Deploy Dashboard (manual/scheduled)

### **4. Verify LaunchAgents**
```bash
# Count active agents
launchctl list | grep -i 02luka | wc -l

# List all agents with status
launchctl list | grep -i 02luka

# Check specific agent logs
tail -20 ~/Library/Logs/02luka/com.02luka.sot.render.err.log
tail -20 ~/Library/Logs/02luka/com.02luka.sot.render.out.log

# Verify agent is loaded
launchctl print gui/$(id -u)/com.02luka.sot.render
```

### **5. Verify Critical Files**
```bash
cd ~/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My\ Drive/02luka/02luka-repo

# Check root-level files
ls -lh 02luka.md README.md CLAUDE.md 02luka_daily.md

# Check workflows
ls -lh .github/workflows/ops-monitoring.yml

# Check recent reports
ls -lht g/reports/*.md | head -5

# Check manual documentation
ls -lh g/manuals/ops_monitoring_cicd.md
```

### **6. Verify Docker (if used)**
```bash
# List running containers
docker ps

# Check container logs
docker logs mcp_gateway 2>&1 | tail -20

# Check container health
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

### **7. Verify Disk Space**
```bash
# Check repo disk usage
df -h ~/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My\ Drive/02luka/02luka-repo

# Check large files
du -sh ~/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My\ Drive/02luka/02luka-repo/* | sort -h | tail -10

# Check git repo size
du -sh ~/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My\ Drive/02luka/02luka-repo/.git
```

---

## 🚨 Troubleshooting

### **Service Not Running**
```bash
# Restart MCP FS Server
pkill -f mcp_fs_server.py
nohup python3 g/tools/mcp_fs_server.py > /tmp/mcp_fs.log 2>&1 &

# Restart Boss API
cd boss-api && pkill -f server.cjs
nohup node server.cjs > /tmp/boss_api.log 2>&1 &

# Restart UI Server
pkill -f "http.server 5173"
nohup python3 -m http.server 5173 --bind 127.0.0.1 > /tmp/ui_server.log 2>&1 &
```

### **GitHub Actions Failed**
```bash
# View failed run logs
gh run list --status failure --limit 5
gh run view <run-id> --log

# Re-run failed workflow
gh run rerun <run-id>

# Trigger manual workflow
gh workflow run "OPS Monitoring"
```

### **LaunchAgent Issues**
```bash
# Unload and reload agent
launchctl unload ~/Library/LaunchAgents/com.02luka.sot.render.plist
launchctl load ~/Library/LaunchAgents/com.02luka.sot.render.plist

# Check agent logs for errors
grep -i error ~/Library/Logs/02luka/*.log

# Verify agent plist syntax
plutil -lint ~/Library/LaunchAgents/com.02luka.sot.render.plist
```

---

## 📋 Complete Health Check Script

```bash
#!/bin/bash
# Save as: ~/check_02luka.sh

echo "═══════════════════════════════════════"
echo "02LUKA SYSTEM HEALTH CHECK"
echo "═══════════════════════════════════════"
echo ""

echo "1. Services Running:"
lsof -i :4000 -i :5173 -i :8765 2>/dev/null | grep LISTEN | awk '{print "  ✅", $1, "on port", $9}'
echo ""

echo "2. GitHub Workflows:"
gh workflow list | head -5 | awk '{print "  ✅", $1, $2, $3}'
echo ""

echo "3. LaunchAgents:"
AGENT_COUNT=$(launchctl list | grep -i 02luka | wc -l | tr -d ' ')
echo "  ✅ $AGENT_COUNT agents running"
echo ""

echo "4. Git Status:"
cd ~/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My\ Drive/02luka/02luka-repo
git status | grep -E "(On branch|Your branch)" | sed 's/^/  ✅ /'
echo ""

echo "5. Disk Space:"
df -h . | tail -1 | awk '{print "  ✅", $4, "available (", $5, "used)"}'
echo ""

echo "6. Latest Commit:"
git log -1 --pretty=format:"  ✅ %h - %s (%ar)%n"
echo ""
echo ""

echo "═══════════════════════════════════════"
echo "Health Check Complete"
echo "═══════════════════════════════════════"
```

**Usage:**
```bash
chmod +x ~/check_02luka.sh
~/check_02luka.sh
```

---

## 📚 Key Documentation References

- **System Dashboard:** `02luka.md` (this file - repo root)
- **OPS Monitoring Manual:** `g/manuals/ops_monitoring_cicd.md` (439 lines)
- **Latest Deployment:** `g/reports/DEPLOYMENT_GITHUB_ACTIONS_251017.md`
- **Reportbot Deployment:** `g/reports/DEPLOYMENT_REPORTBOT_251016.md`

---

**Last Verified:** 2025-10-17
**Services:** 3/3 running ✅
**Workflows:** 10/10 active ✅
**LaunchAgents:** 36/36 loaded ✅
