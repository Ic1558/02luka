# 02LUKA Local Services (Native)

**อัปเดต:** 2025-11-06

## 🌐 Core Services

### Redis Server
- **URL:** redis://127.0.0.1:6379
- **Password:** gggclukaic
- **Status:** ✅ Running (PID: 96200)
- **Command:** `/opt/homebrew/opt/redis/bin/redis-server`
- **Verified:** PING=PONG ✅

### Dashboard API
- **URL:** http://127.0.0.1:8766
- **Status:** ✅ Running (PID: 61837)
- **Command:** `python3 api_server.py`
- **Log:** `/tmp/api_server.log`

### Cloudflared Tunnels
- **Dashboard Tunnel:** ✅ Running (PID: 12975)
  - Config: `~/.cloudflared/dashboard.yml`
  - Routes: `n8n.theedges.work` → `localhost:5678`, `ops.theedges.work` → `localhost:4000`
- **NAS Archive Tunnel:** ✅ Running (PID: 13034)
  - Config: `~/.cloudflared/nas-archive.yml`
  - Routes: `archive.theedges.work` → `192.168.1.58:5000`

> **หมายเหตุ:** Docker Desktop ทำงานอยู่ได้ แต่ **ไม่มีคอนเทนเนอร์ที่รันอยู่** (ถูกต้องแล้ว - เราใช้ Native services)

---

## 🤖 MCP Servers (Model Context Protocol)

### แนวทาง: Native-First

**ติดตั้งด้วย:**
- Python: `uvx` หรือ `pipx install <mcp-server>`
- Node: `npm install -g <mcp-server>` หรือ `npx <mcp-server>`

**โครงสร้างแนะนำ:**
```
~/02luka/mcp/
  servers/<name>/
  config/<name>.json
  logs/<name>.log
```

### MCP Servers ที่รันอยู่

**1. MCP Filesystem**
- **Status:** ✅ Configured
- **Command:** `/Users/icmini/.local/bin/mcp_fs`
- **Package:** `@modelcontextprotocol/server-filesystem`
- **Paths:** Google Drive 02luka folders

**2. MCP Docker Gateway**
- **Status:** ⚠️ Running but backend down
- **PID:** 24283
- **Backend API:** http://127.0.0.1:5012 (NOT accessible)
- **Tools:** Docker container management

**3. MCP FastVLM**
- **Status:** ⚠️ Running but backend down
- **PID:** 24285
- **Backend API:** http://127.0.0.1:5012 (shared with Docker Gateway)
- **Purpose:** Apple FastVLM 0.5B vision model

**4. MCP Puppeteer**
- **Status:** ✅ Running
- **PID:** 24313
- **Command:** NPX `@hisma/server-puppeteer`
- **Purpose:** Browser automation

**5. Claude Extensions**
- chrome-control ✅
- osascript (AppleScript) ✅
- apple-notes ✅
- pdf-tools ✅

### LaunchAgent Template สำหรับ MCP

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.02luka.mcp.<name></string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/zsh</string>
        <string>-lc</string>
        <string>uvx <mcp-server> --config $HOME/02luka/mcp/config/<name>.json</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/Users/icmini/02luka/mcp/logs/<name>.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/icmini/02luka/mcp/logs/<name>.err.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
    </dict>
</dict>
</plist>
```

---

## 🏗️ สถาปัตยกรรม (Architecture Overview)

```
┌─────────────────────────────────────────────────┐
│  Native Services (macOS)                        │
│                                                  │
│  ✅ Homebrew Redis (127.0.0.1:6379)            │
│  ✅ Python Dashboard API (127.0.0.1:8766)      │
│  ✅ Cloudflared Tunnels (external access)      │
│  ✅ MCP Servers (LaunchAgents)                 │
│                                                  │
│  Docker Desktop (Running, 0 containers)         │
│  └─ เก็บไว้สำหรับ fallback เฉพาะกรณี          │
└─────────────────────────────────────────────────┘
```

---

## 📂 Data Locations

**Active Working Directory:**
```
~/02luka/g/                    96GB (Mac internal SSD)
├── reports/                   ✅ ใช้งานจริง
├── knowledge/                 ✅ ใช้งานจริง
├── metrics/                   ✅ ใช้งานจริง
└── apps/dashboard/            ✅ รัน API อยู่ที่นี่
```

**Backup Storage (Archive Only):**
```
/Volumes/lukadata/             752GB (External SSD)
├── 02luka_archives/           📦 backups
├── 02luka_snapshots/          📦 snapshots
└── docker-data/               📦 ไม่ได้ใช้
```

**⚠️ สำคัญ:** ระบบ**ไม่ได้ใช้** `/Volumes/lukadata` เป็น working directory แล้ว
ทุกอย่างทำงานจาก `~/02luka` (Mac SSD) ซึ่งเร็วกว่าและไม่มีปัญหา permission

---

## 🔧 Quick Commands

### Check Service Status
```bash
# Check all services
lsof -nP -iTCP -sTCP:LISTEN | grep -E ":(3002|6379|8766|4000|5678)"

# Check Redis
redis-cli -h 127.0.0.1 -p 6379 -a gggclukaic PING

# Check Dashboard
curl -s http://127.0.0.1:8766/health
```

### Open in Browser
```bash
# Dashboard API
open http://127.0.0.1:8766

# External access (via Cloudflare tunnels)
open https://ops.theedges.work
open https://n8n.theedges.work
open https://archive.theedges.work
```

### Restart Services
```bash
# Restart Dashboard
pkill -f "api_server.py" && cd ~/02luka/g/apps/dashboard && python3 api_server.py &

# Restart Redis (via Homebrew)
brew services restart redis

# Check MCP LaunchAgents
launchctl list | grep com.02luka.mcp
```

---

## 🛠️ Troubleshooting

### Docker Desktop ว่างเปล่า - ปกติหรือไม่?
**✅ ปกติ!** เราไม่ใช้ Docker containers สำหรับ core services อีกต่อไป
ทุกอย่างรันแบบ Native เพื่อความเร็วและหลีกเลี่ยง permission issues

### MCP Server ไม่ทำงาน
```bash
# ดู logs
tail -f ~/02luka/mcp/logs/<name>.log

# Check LaunchAgent
launchctl list | grep mcp

# Restart specific MCP
launchctl unload ~/Library/LaunchAgents/com.02luka.mcp.<name>.plist
launchctl load ~/Library/LaunchAgents/com.02luka.mcp.<name>.plist
```

### Service ไม่ตอบสนอง
```bash
# Check if port is in use
lsof -i :8766

# Check logs
tail -50 /tmp/api_server.log

# Restart service
pkill -f "api_server.py"
cd ~/02luka/g/apps/dashboard && python3 api_server.py &
```

### Redis ไม่เข้าถึงได้
```bash
# Check Redis status
brew services list | grep redis

# Restart Redis
brew services restart redis

# Verify
redis-cli -h 127.0.0.1 -p 6379 -a gggclukaic PING
```

---

## 🔗 External Access (ถ้าต้องการ)

**Check your Mac's IP:**
```bash
ipconfig getifaddr en0
```

**Access via Mac IP:**
```
http://<YOUR_MAC_IP>:8766
```

**Or use Cloudflared tunnels** (already running):
- `ops.theedges.work` → Dashboard (port 4000)
- `n8n.theedges.work` → N8N (port 5678)
- `archive.theedges.work` → NAS Archive

---

## 📚 Related Documentation

- `DOCKER_TO_NATIVE_MIGRATION.md` - ประวัติการย้ายจาก Docker
- `AGENTS.md` - System rules and architecture
- `CLS.md` - CLS orchestrator documentation
- `GIT_WORKFLOW_GUIDE.md` - Git best practices

---

**Quick Reference:** All services run natively on macOS - no Docker needed for daily operations! 🚀
