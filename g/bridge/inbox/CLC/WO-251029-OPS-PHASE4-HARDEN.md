# Work Order: WO-251029-OPS-PHASE4-HARDEN

**Date:** 2025-10-29
**Phase:** 4 - Hardening & Production Readiness
**Agent:** CLC
**Priority:** HIGH
**Status:** DROPPED

---

## 🎯 Objectives

Replace stub services with real implementations and harden operations infrastructure:

1. **Health Proxy** (`gateway/health_proxy.js` - port 3002)
2. **MCP WebBridge** (`run/mcp_webbridge.cjs` - port 3003)
3. **Boss API** (`api/boss_api.cjs` - port 4000)

Provide production-grade components:
- LaunchAgents with KeepAlive and crash recovery
- CI workflows for automated testing
- Comprehensive verification suite
- SLO definitions and monitoring
- Auto-heal integration

---

## 📋 Requirements

### Service Implementation

**Language:** Node.js (CommonJS)
**Dependencies:** Minimal - native `http` module + existing libs only

**Required Endpoints:**
- `GET /health` → `{ok: boolean, details: object, timestamp: ISO8601}`
- `GET /metrics` → Prometheus format text

**Prometheus Metrics:**
- `service_up` (gauge): 1 = up, 0 = down
- `http_requests_total` (counter): Total requests by endpoint
- `http_request_duration_ms` (histogram): Request latencies
- `errors_total` (counter): Total errors by type

**Integrations:**
- Import `run/lib/circuit_breaker.cjs` (Phase 2)
- Import `run/auto_heal.cjs` (Phase 2)
- Emit metrics via `run/lib/metrics_collector.cjs` (Phase 3)
- Record history via `run/lib/health_history.cjs` (Phase 3)

**Configuration:**
- Read from `config/services.monitor.json`
- Logs → `g/logs/<service>.log`
- State → `g/state/<service>_state.json`

---

## 🔧 Service Specifications

### 1. Health Proxy (gateway/health_proxy.js)

**Purpose:** Aggregate health status from all services

**Port:** 3002

**Endpoints:**
- `GET /health` - Own health status
- `GET /health/all` - Aggregated system health
- `GET /metrics` - Prometheus metrics

**Features:**
- Query all services from `config/services.monitor.json`
- Parallel health checks with timeout
- Circuit breaker integration
- Health score calculation (0-100)
- Cache successful checks (2-min TTL)

### 2. MCP WebBridge (run/mcp_webbridge.cjs)

**Purpose:** Model Context Protocol bridge for cross-AI tool access

**Port:** 3003

**Endpoints:**
- `GET /health` - Service health
- `GET /tools` - List available MCP tools
- `POST /tools/:name` - Execute tool
- `GET /servers` - List MCP servers
- `GET /metrics` - Prometheus metrics

**Features:**
- MCP server registry
- Tool execution with timeout
- Request/response logging
- Circuit breaker per tool
- Rate limiting

**Initial Implementation:**
- Stub tool registry (empty list)
- Placeholder for future MCP integration
- Full metrics and health endpoints
- Ready for tool registration

### 3. Boss API (api/boss_api.cjs)

**Purpose:** Boss workflow orchestration API

**Port:** 4000

**Endpoints:**
- `GET /healthz` - Health check (legacy path)
- `GET /health` - Health check (standard path)
- `GET /status` - System status
- `POST /workflow/:id/start` - Start workflow
- `GET /workflow/:id/status` - Workflow status
- `GET /metrics` - Prometheus metrics

**Features:**
- Workflow state management
- Integration with Boss system
- Task queue management
- Circuit breaker integration
- Comprehensive logging

**Initial Implementation:**
- Health and metrics endpoints working
- Workflow endpoints return stub data
- Ready for Boss integration
- Full observability

---

## 🔄 Wrapper Scripts

Create resilient wrappers with crash recovery:

**Location:** `run/wrappers/`

**Files:**
- `health_proxy.zsh`
- `mcp_webbridge.zsh`
- `boss_api.zsh`

**Pattern:**
```zsh
#!/usr/bin/env zsh
set -euo pipefail

SERVICE="health_proxy"
PORT=3002
SCRIPT="gateway/health_proxy.js"
REPO="/Users/icmini/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka/02luka-repo"

cd "$REPO"

while true; do
  echo "[$(date)] Starting $SERVICE on port $PORT" | tee -a g/logs/${SERVICE}_wrapper.log

  if node "$SCRIPT"; then
    echo "[$(date)] $SERVICE exited cleanly" | tee -a g/logs/${SERVICE}_wrapper.log
  else
    EXIT_CODE=$?
    echo "[$(date)] $SERVICE crashed with exit code $EXIT_CODE" | tee -a g/logs/${SERVICE}_wrapper.log
  fi

  echo "[$(date)] Waiting 300s before restart..." | tee -a g/logs/${SERVICE}_wrapper.log
  sleep 300
done
```

---

## 📱 LaunchAgents

**Location:** `~/Library/LaunchAgents/`

**Files:**
- `com.02luka.health.proxy.plist`
- `com.02luka.mcp.webbridge.plist`
- `com.02luka.boss.api.plist`

**Pattern:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.02luka.health.proxy</string>

  <key>ProgramArguments</key>
  <array>
    <string>/bin/zsh</string>
    <string>run/wrappers/health_proxy.zsh</string>
  </array>

  <key>WorkingDirectory</key>
  <string>/Users/icmini/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka/02luka-repo</string>

  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    <key>NODE_ENV</key>
    <string>production</string>
  </dict>

  <key>RunAtLoad</key>
  <true/>

  <key>KeepAlive</key>
  <true/>

  <key>StandardOutPath</key>
  <string>/Users/icmini/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka/02luka-repo/g/logs/health_proxy.out.log</string>

  <key>StandardErrorPath</key>
  <string>/Users/icmini/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka/02luka-repo/g/logs/health_proxy.err.log</string>

  <key>ThrottleInterval</key>
  <integer>10</integer>
</dict>
</plist>
```

**Validation:** All plists must pass `plutil -lint`

---

## 🔄 CI Workflow

**File:** `.github/workflows/ops_phase4.yml`

**Jobs:**

### 1. Build
- Checkout code
- Setup Node.js
- Verify all service files exist
- Check syntax: `node --check <file>`

### 2. Test
- Unit tests (if any)
- Lint checks
- Config validation

### 3. Smoke Test
- Start services locally (non-daemon)
- Wait for ports to open (nc -z)
- Curl /health endpoints
- Verify 200 responses
- Check /metrics format
- Stop services

**Artifacts:**
- Upload dashboard JSON
- Upload service logs
- Upload test results

---

## 📊 SLOs (Service Level Objectives)

### Availability
- **Target:** ≥ 99.5% weekly
- **Measurement:** Uptime checks every 5 minutes
- **Tracking:** Health history over 7 days

### Performance
- **Target:** p95 health check ≤ 200ms
- **Measurement:** Latency metrics from health_history
- **Tracking:** Dashboard percentiles

### Reliability
- **Target:** < 3 restarts per week per service
- **Measurement:** Auto-heal logs
- **Tracking:** Restart counter in metrics

### Alerting Thresholds

**CRITICAL:**
- 3 consecutive health check failures
- Cooldown: 1 hour
- Channels: Discord, log, email

**WARNING:**
- 5 failures in 24 hours
- Cooldown: 2 hours
- Channels: Log

**INFO:**
- Service restart
- Cooldown: 4 hours
- Channels: Log

---

## 📝 Deliverables

### Service Files (3)
1. `gateway/health_proxy.js` - Real implementation
2. `run/mcp_webbridge.cjs` - Real implementation
3. `api/boss_api.cjs` - Real implementation

### Wrapper Scripts (3)
4. `run/wrappers/health_proxy.zsh`
5. `run/wrappers/mcp_webbridge.zsh`
6. `run/wrappers/boss_api.zsh`

### LaunchAgents (3)
7. `~/Library/LaunchAgents/com.02luka.health.proxy.plist`
8. `~/Library/LaunchAgents/com.02luka.mcp.webbridge.plist`
9. `~/Library/LaunchAgents/com.02luka.boss.api.plist`

### CI/CD (1)
10. `.github/workflows/ops_phase4.yml`

### Scripts (2)
11. `scripts/verify_phase4_harden.sh` - Verification suite
12. Update `scripts/status.sh` - Add Phase 4 checks

### Documentation (2)
13. `g/reports/251029_PHASE4_HARDEN_PLAN.md` - Implementation plan
14. `g/reports/251029_PHASE4_HARDEN_COMPLETE.md` - Completion report

---

## ✅ Verification Script Specification

**File:** `scripts/verify_phase4_harden.sh`

**Checks:**

1. **File Existence**
   - All 3 service files
   - All 3 wrapper scripts
   - All 3 LaunchAgent plists
   - CI workflow file

2. **Syntax Validation**
   - `node --check` on all .js/.cjs files
   - `plutil -lint` on all .plist files
   - `zsh -n` on all .zsh files

3. **Local Service Test**
   - Start each service in background
   - Wait for port to open (timeout 30s)
   - Curl GET /health (expect 200)
   - Curl GET /metrics (expect text/plain with metrics)
   - Stop service
   - Check logs for errors

4. **LaunchAgent Test** (macOS only)
   - Unload existing agents
   - Load new agents
   - Verify `launchctl list | grep` shows all 3
   - Wait 10s for startup
   - Port check all 3 services
   - Health check all 3 services

5. **Integration Test**
   - Call health_proxy /health/all
   - Verify it queries other services
   - Check circuit breaker states
   - Verify metrics collection

6. **Report Generation**
   - Create `g/reports/phase4/verify_YYYYMMDD_HHMM.md`
   - PASS/FAIL table
   - Error details if any
   - Recommendations

---

## 🔄 Rollback Plan

If Phase 4 deployment fails:

```bash
# 1. Unload new LaunchAgents
launchctl unload ~/Library/LaunchAgents/com.02luka.health.proxy.plist
launchctl unload ~/Library/LaunchAgents/com.02luka.mcp.webbridge.plist
launchctl unload ~/Library/LaunchAgents/com.02luka.boss.api.plist

# 2. Reload stub LaunchAgents (from Phase 3)
launchctl load ~/Library/LaunchAgents/com.02luka.health.proxy.stub.plist
launchctl load ~/Library/LaunchAgents/com.02luka.mcp.bridge.stub.plist
launchctl load ~/Library/LaunchAgents/com.02luka.boss.api.stub.plist

# 3. Verify stubs are running
scripts/status.sh

# 4. Review logs for root cause
tail -100 g/logs/health_proxy.err.log
tail -100 g/logs/mcp_webbridge.err.log
tail -100 g/logs/boss_api.err.log
```

**Rollback Decision Criteria:**
- Any service fails to start after 3 attempts
- Health checks fail for >10 minutes
- Critical errors in logs
- System health score drops below 50/100

---

## 📋 Implementation Checklist

- [ ] Create all 3 real service implementations
- [ ] Create all 3 wrapper scripts (executable)
- [ ] Create all 3 LaunchAgent plists (valid XML)
- [ ] Create CI workflow file
- [ ] Create verification script (executable)
- [ ] Update status.sh script
- [ ] Create implementation plan document
- [ ] Test locally before LaunchAgent deployment
- [ ] Deploy LaunchAgents
- [ ] Run full verification suite
- [ ] Monitor for 1 hour post-deployment
- [ ] Create completion report

---

## 🎯 Success Criteria

| Metric | Target | Measurement |
|--------|--------|-------------|
| All services responding | 3/3 | Port checks + health endpoints |
| Health checks < 200ms | p95 | Metrics collector |
| LaunchAgents loaded | 3/3 | launchctl list |
| Syntax validation | 100% pass | plutil + node --check |
| Integration tests | All pass | verify_phase4_harden.sh |
| No critical errors | 0 | Error logs review |

---

## 📝 Notes

- Keep Phase 3 stub files as backup (rename with .stub extension)
- Maintain idempotency - script can be re-run safely
- All services must integrate with existing Phase 2+3 infrastructure
- SLO tracking begins after 24h baseline period
- Auto-heal will manage service restarts automatically

---

**Work Order Status:** DROPPED - Ready for Implementation

**Expected Duration:** 2-3 hours
**Agent:** CLC
**Approver:** Boss System
**Deployment Window:** Immediate (non-breaking change)

---

*Dropped: 2025-10-29*
*Work Order ID: WO-251029-OPS-PHASE4-HARDEN*
*Phase: 4 - Hardening*
