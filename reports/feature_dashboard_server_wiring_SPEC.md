# Dashboard Server Wiring - SPEC

**Date:** 2025-11-13  
**Feature:** Fix Dashboard Server Auto-Start and Wiring  
**Status:** 🔴 CRITICAL

---

## Objective

Ensure `wo_dashboard_server.js` starts automatically on login and stays running, providing API endpoints for the dashboard to function correctly.

---

## Problem Statement

**Current State:**
- `wo_dashboard_server.js` exists but is **not running**
- No LaunchAgent configured to auto-start the server
- Dashboard cannot access API endpoints (returns 404/connection errors)
- Manual start required every time

**Impact:**
- Dashboard is non-functional without manual intervention
- WO actions (activate/pause/complete) don't work
- API endpoints unavailable
- Poor user experience

---

## Root Cause Analysis

1. **Missing LaunchAgent:** No `.plist` file to auto-start `wo_dashboard_server.js`
   - **Note:** Existing `com.02luka.dashboard.server` runs static file server (port 8000)
   - **Need:** NEW LaunchAgent specifically for API server (port 8765)
2. **No Auto-Restart:** Server crashes are not handled
3. **No Health Monitoring:** No way to detect if server is down
4. **Port Conflicts:** No handling for port already in use

**Architecture:**
- **Static Server (port 8000):** ✅ Running via `com.02luka.dashboard.server`
  - Serves HTML/CSS/JS files
  - Python HTTP server
- **API Server (port 8765):** ❌ Missing
  - Provides REST API endpoints
  - Node.js server (`wo_dashboard_server.js`)
  - **This is what needs to be fixed**

---

## Solution Approach

### 1. Create LaunchAgent
- **File:** `~/Library/LaunchAgents/com.02luka.wo_dashboard_server.plist`
- **Purpose:** Auto-start API server on login
- **Note:** This is SEPARATE from existing `com.02luka.dashboard.server` (static file server)
- **Features:**
  - KeepAlive: true (auto-restart on crash)
  - RunAtLoad: true (start immediately)
  - ThrottleInterval: 30 (prevent rapid restarts)
  - StandardOut/StandardError logging

### 2. Environment Setup
- **Variables:**
  - `LUKA_SOT` - Base directory
  - `REDIS_PASSWORD` - Redis auth (from env)
  - `DASHBOARD_PORT` - Server port (default: 8765)
  - `DASHBOARD_AUTH_TOKEN` - API auth token

### 3. Server Improvements
- **Port Conflict Handling:** Check if port in use, use next available
- **Health Endpoint:** `GET /health` for monitoring
- **Graceful Shutdown:** Handle SIGTERM/SIGINT

### 4. Verification
- **Health Check Script:** `tools/check_dashboard_server.zsh`
- **Auto-test on start:** Verify endpoints respond
- **Log Monitoring:** Check for errors

---

## Technical Details

### LaunchAgent Configuration

```xml
<key>ProgramArguments</key>
<array>
  <string>/usr/bin/env</string>
  <string>node</string>
  <string>/Users/icmini/02luka/g/apps/dashboard/wo_dashboard_server.js</string>
</array>
<key>EnvironmentVariables</key>
<dict>
  <key>LUKA_SOT</key>
  <string>/Users/icmini/02luka</string>
  <key>REDIS_PASSWORD</key>
  <string>gggclukaic</string>
  <key>DASHBOARD_PORT</key>
  <string>8765</string>
</dict>
<key>KeepAlive</key>
<true/>
<key>RunAtLoad</key>
<true/>
<key>ThrottleInterval</key>
<integer>30</integer>
<key>StandardOutPath</key>
<string>/Users/icmini/02luka/logs/wo_dashboard_server.stdout.log</string>
<key>StandardErrorPath</key>
<string>/Users/icmini/02luka/logs/wo_dashboard_server.stderr.log</string>
```

### Server Enhancements

1. **Port Conflict Detection:**
   ```javascript
   const checkPort = (port) => {
     return new Promise((resolve) => {
       const server = http.createServer();
       server.listen(port, () => {
         server.close(() => resolve(true));
       });
       server.on('error', () => resolve(false));
     });
   };
   ```

2. **Health Endpoint:**
   ```javascript
   if (pathname === '/health') {
     return sendJSON(res, 200, {
       ok: true,
       service: 'wo-dashboard-server',
       port: PORT,
       redis: redisClient ? 'connected' : 'disconnected'
     });
   }
   ```

3. **Graceful Shutdown:**
   ```javascript
   process.on('SIGTERM', async () => {
     console.log('SIGTERM received, shutting down gracefully');
     if (redisClient) await redisClient.quit();
     server.close(() => process.exit(0));
   });
   ```

---

## Success Criteria

- ✅ Server starts automatically on login
- ✅ Server restarts automatically on crash
- ✅ Health endpoint responds: `GET /health`
- ✅ API endpoints accessible: `/api/wos`, `/api/auth-token`
- ✅ Logs written to `logs/wo_dashboard_server.*.log`
- ✅ No manual intervention required

---

## Dependencies

- Node.js (already installed)
- Redis (already running)
- LaunchAgent directory: `~/Library/LaunchAgents/`
- Logs directory: `~/02luka/logs/`

---

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Port conflict | Medium | Check port availability, use next available |
| Redis connection failure | Low | Server continues, Redis optional |
| LaunchAgent permission issues | Low | Verify plist syntax, check permissions |
| Log directory missing | Low | Create directory in setup |

---

## References

- LaunchAgent docs: `~/02luka/02luka.md` (LaunchAgents section)
- Redis config: `~/02luka/config/` (Redis password)
- Dashboard server: `g/apps/dashboard/wo_dashboard_server.js`
