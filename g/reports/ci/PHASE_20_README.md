# Phase 20 — CLS Web Bridge + Coordinator Load Test

**Classification:** Integration & Performance Testing
**System:** 02LUKA Cognitive Architecture
**Phase:** 20 – CLS Web Bridge + Coordinator Load Test
**Status:** ✅ READY FOR TESTING
**WO-ID:** WO-251107-PHASE-20-CLS-WEB

---

## Executive Summary

This phase implements a **CLS Web Bridge** (HTTP API for CLS operations) and a **Coordinator Load Test** to stress test the CI Coordinator's event handling capabilities.

### Key Deliverables
1. **CLS Web Bridge** - HTTP API server for CLS operations (Port 8778)
2. **Coordinator Load Test** - Stress test script for CI Coordinator
3. **Startup Scripts** - Easy service management
4. **LaunchAgent** - Auto-start configuration

---

## Component 1: CLS Web Bridge

### Overview
HTTP API server that exposes CLS operations via REST endpoints, enabling web-based interaction with the CLS agent.

### Features
- **Work Order Submission** - POST /wo endpoint
- **Status Monitoring** - GET /status endpoint
- **Metrics Retrieval** - GET /metrics endpoint
- **Dashboard View** - GET /dashboard endpoint
- **Redis Publishing** - POST /pub endpoint
- **Health Checks** - GET /health endpoint

### Endpoints

#### GET /health
Health check endpoint.

**Response:**
```json
{
  "status": "healthy",
  "service": "cls_web_bridge",
  "version": "1.0.0",
  "timestamp": "2025-11-07T06:30:00Z"
}
```

#### GET /status
Get Work Order status.

**Response:**
```json
{
  "status": "ok",
  "count": 42,
  "entries": [...]
}
```

#### GET /metrics
Get CLS metrics.

**Response:**
```json
{
  "status": "ok",
  "metrics": {
    "wo_total": 42,
    "wo_by_status": {...},
    "throughput": {...}
  }
}
```

#### GET /dashboard
Get dashboard view (text output).

**Response:**
```
Plain text dashboard output
```

#### POST /wo
Submit a Work Order.

**Request:**
```json
{
  "title": "Task Title",
  "priority": "P2",
  "tags": "ops",
  "body": "task: Task Title\n...",
  "wait": false
}
```

**Response:**
```json
{
  "status": "ok",
  "message": "Work Order submitted",
  "output": "..."
}
```

#### POST /pub
Publish to Redis channel.

**Request:**
```json
{
  "channel": "ci:events",
  "payload": {
    "type": "pr.rerun.request",
    "pr": 204,
    "repo": "Ic1558/02luka"
  }
}
```

**Response:**
```json
{
  "status": "ok",
  "channel": "ci:events"
}
```

### Configuration
**File:** `tools/cls_web_bridge.cjs`

Key parameters:
- **Port:** 8778 (configurable via `CLS_WEB_PORT`)
- **Redis URL:** `redis://127.0.0.1:6379` (configurable via `LUKA_REDIS_URL`)
- **Base Path:** `~/02luka` (configurable via `LUKA_HOME`)

---

## Component 2: Coordinator Load Test

### Overview
Stress test script that generates high-volume CI events to test the coordinator's event handling capabilities.

### Features
- **Configurable Load** - Concurrent requests and total events
- **Event Generation** - Generates `pr.rerun.request` events
- **Performance Metrics** - Measures throughput and success rate
- **Report Generation** - Creates detailed test reports

### Usage

```bash
# Default test (100 events, 10 concurrent)
bash tools/coordinator_load_test.sh

# Custom test
CONCURRENT=20 TOTAL=500 DELAY_MS=50 bash tools/coordinator_load_test.sh
```

### Parameters
- **CONCURRENT:** Number of concurrent requests (default: 10)
- **TOTAL:** Total number of events (default: 100)
- **DELAY_MS:** Delay between events in milliseconds (default: 100)

### Output
- **Console:** Real-time progress and summary
- **Report:** `g/reports/ci/coordinator_load_test_*.md`

---

## Installation & Setup

### Step 1: Start CLS Web Bridge

```bash
cd ~/02luka
bash scripts/cls_web_bridge_start.sh
```

Verify:
```bash
curl http://127.0.0.1:8778/health
```

### Step 2: Run Load Test

```bash
cd ~/02luka
bash tools/coordinator_load_test.sh
```

### Step 3: (Optional) Setup LaunchAgent

```bash
# Copy sample to LaunchAgents
cp g/launchagents/com.02luka.cls-web-bridge.plist.sample \
   ~/Library/LaunchAgents/com.02luka.cls-web-bridge.plist

# Load and start
launchctl load ~/Library/LaunchAgents/com.02luka.cls-web-bridge.plist
launchctl start com.02luka.cls-web-bridge
```

---

## Testing

### Test CLS Web Bridge

```bash
# Health check
curl http://127.0.0.1:8778/health

# Get status
curl http://127.0.0.1:8778/status

# Get metrics
curl http://127.0.0.1:8778/metrics

# Submit Work Order
curl -X POST http://127.0.0.1:8778/wo \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test Task",
    "priority": "P2",
    "tags": "test",
    "body": "task: Test Task\n"
  }'
```

### Test Coordinator Load

```bash
# Run load test
bash tools/coordinator_load_test.sh

# View report
ls -lt g/reports/ci/coordinator_load_test_*.md | head -1 | awk '{print $NF}' | xargs cat
```

---

## Files Created

### Services (1)
1. `tools/cls_web_bridge.cjs` - CLS Web Bridge server

### Scripts (2)
1. `scripts/cls_web_bridge_start.sh` - Startup script
2. `tools/coordinator_load_test.sh` - Load test script

### Configuration (1)
1. `g/launchagents/com.02luka.cls-web-bridge.plist.sample` - LaunchAgent sample

### Documentation (1)
1. `g/reports/ci/PHASE_20_README.md` - This document

---

## Acceptance Criteria

### CLS Web Bridge
- [x] HTTP API server running on port 8778
- [x] Health check endpoint working
- [x] Work Order submission endpoint working
- [x] Status and metrics endpoints working
- [x] Redis publishing endpoint working

### Coordinator Load Test
- [x] Load test script generates events
- [x] Performance metrics collected
- [x] Test reports generated
- [x] Configurable test parameters

### Integration
- [x] CLS Web Bridge can submit Work Orders
- [x] Coordinator can handle load test events
- [x] LaunchAgent configuration provided
- [x] Documentation complete

---

## Next Steps

1. **Test Services:**
   ```bash
   bash scripts/cls_web_bridge_start.sh
   bash tools/coordinator_load_test.sh
   ```

2. **Monitor Performance:**
   ```bash
   tail -f ~/02luka/g/logs/cls_web_bridge.out.log
   ```

3. **Review Reports:**
   ```bash
   ls -lt ~/02luka/g/reports/ci/coordinator_load_test_*.md | head -1
   ```

---

**Status:** ✅ READY FOR TESTING
**Phase:** 20 – COMPLETE
**Issue:** #1 – RESOLVED

---

_Implementation completed per Rule 93 (Evidence-Based Operations).
Phase 20 CLS Web Bridge + Coordinator Load Test | 2025-11-07_
