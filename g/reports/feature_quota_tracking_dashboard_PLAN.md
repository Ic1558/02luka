# Feature: Quota Tracking & Dashboard Token Widget

**Status:** SPEC (Planning Phase)  
**Date:** 2025-11-19  
**Requested Via:** `/feature-dev`  
**Next PR After:** Gemini Routing + WO Integration

---

## 1. Problem Statement

Currently, the 02luka system lacks real-time visibility into token/quota usage across agents:
- **Gemini API:** No dashboard widget showing current quota consumption
- **GPT/Codex/CLC:** No unified quota tracking across all agents
- **Token Monitoring:** CLC warns at 150K, alerts at 180K, fallback at 190K+ (per Protocol v3.2), but no visual dashboard
- **Cost Tracking:** No per-agent cost breakdown or daily/monthly limits

**Impact:**
- Cannot proactively manage quota exhaustion
- No visibility into which agents consume most tokens
- Cannot set per-agent quotas or budgets
- Fallback triggers are reactive, not proactive

---

## 2. Goals

### Primary Goals
1. **Real-time quota dashboard widget** showing:
   - Current token usage per agent (Gemini, GPT, Codex, CLC)
   - Daily/monthly limits and remaining quota
   - Cost breakdown (if available from API providers)
   - Visual indicators (green/yellow/red) for quota health

2. **Quota tracking backend:**
   - Track token usage per agent per request
   - Store historical data (daily/monthly aggregates)
   - Expose API endpoints for dashboard consumption
   - Support quota limits and alerts

3. **Integration with existing systems:**
   - Hook into agent request handlers (Gemini API, GPT, Codex, CLC)
   - Respect Protocol v3.2 token monitoring rules (150K/180K/190K thresholds)
   - Log to MLS for quota events (exhaustion, fallback triggers)

### Secondary Goals
- Per-agent quota budgets (configurable limits)
- Quota exhaustion notifications (Telegram, dashboard alerts)
- Historical quota trends (charts/graphs)
- Cost estimation (if API pricing available)

---

## 3. Technical Approach

### 3.1 Architecture

```
┌─────────────────┐
│  Dashboard UI   │  ← Token widget (real-time)
│  (dashboard.js) │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Quota API      │  ← /api/quota/status, /api/quota/history
│  (api_server.py)│
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Quota Store    │  ← Redis (real-time) + SQLite/JSONL (historical)
│  (quota_tracker)│
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Agent Handlers │  ← Gemini, GPT, Codex, CLC (instrumentation)
│  (hooks)        │
└─────────────────┘
```

### 3.2 Components

#### A. Quota Tracker Module (`g/tools/quota_tracker.py`)
- **Responsibilities:**
  - Track token usage per agent per request
  - Store in Redis (real-time) and JSONL (historical)
  - Calculate daily/monthly aggregates
  - Check quota limits and trigger alerts

- **Data Model:**
  ```python
  {
    "agent": "gemini",
    "timestamp": "2025-11-19T10:30:00Z",
    "tokens_used": 1500,
    "request_id": "req_123",
    "cost_usd": 0.0015,  # optional
    "daily_total": 45000,
    "monthly_total": 1200000
  }
  ```

#### B. Quota API Endpoints (`g/apps/dashboard/api_server.py`)
- **Endpoints:**
  - `GET /api/quota/status` → Current quota per agent
  - `GET /api/quota/history?agent=gemini&days=7` → Historical data
  - `GET /api/quota/limits` → Configured limits per agent

- **Response Format:**
  ```json
  {
    "gemini": {
      "current": 45000,
      "daily_limit": 100000,
      "monthly_limit": 2000000,
      "status": "healthy",  // healthy/warning/critical
      "remaining": 55000,
      "cost_today_usd": 0.45
    },
    "gpt": { ... },
    "codex": { ... },
    "clc": { ... }
  }
  ```

#### C. Dashboard Widget (`g/apps/dashboard/dashboard.js`)
- **UI Component:**
  - Real-time quota cards per agent
  - Progress bars (current/limit)
  - Status indicators (green/yellow/red)
  - Auto-refresh every 30 seconds

- **Layout:**
  ```
  ┌─────────────────────────────────────┐
  │  Quota Status                      │
  ├─────────────────────────────────────┤
  │  Gemini: [████████░░] 45K/100K     │
  │  GPT:    [█████░░░░░] 25K/80K       │
  │  Codex:  [██░░░░░░░░] 10K/50K       │
  │  CLC:    [███████░░░] 35K/60K       │
  └─────────────────────────────────────┘
  ```

#### D. Agent Instrumentation Hooks
- **Gemini API Handler:** Track tokens after each API call
- **GPT Handler:** Track tokens (if available)
- **Codex Handler:** Track tokens (if available)
- **CLC Handler:** Track tokens (if available)

- **Hook Pattern:**
  ```python
  def track_quota(agent, tokens_used, request_id=None):
      quota_tracker.record(agent, tokens_used, request_id)
      if quota_tracker.is_limit_exceeded(agent):
          trigger_alert(agent)
  ```

### 3.3 Storage Strategy

- **Redis (Real-time):**
  - Keys: `quota:gemini:daily`, `quota:gemini:monthly`
  - TTL: 24 hours (daily), 30 days (monthly)
  - Fast reads for dashboard

- **JSONL (Historical):**
  - File: `g/reports/quota/quota_history.jsonl`
  - Append-only log for analytics
  - Can be queried for trends

- **Config (Limits):**
  - File: `config/quota_limits.yaml`
  ```yaml
  agents:
    gemini:
      daily_limit: 100000
      monthly_limit: 2000000
      warning_threshold: 0.8  # 80% of limit
    gpt:
      daily_limit: 80000
      monthly_limit: 1500000
    # ...
  ```

---

## 4. Implementation Tasks

### Phase 1: Backend Quota Tracker
- [ ] Create `g/tools/quota_tracker.py` module
- [ ] Implement Redis storage for real-time quotas
- [ ] Implement JSONL storage for historical data
- [ ] Add quota limit configuration (`config/quota_limits.yaml`)
- [ ] Add quota check/alert logic

### Phase 2: API Endpoints
- [ ] Add `/api/quota/status` endpoint to `api_server.py`
- [ ] Add `/api/quota/history` endpoint
- [ ] Add `/api/quota/limits` endpoint
- [ ] Test API responses with sample data

### Phase 3: Dashboard Widget
- [ ] Create quota widget component in `dashboard.js`
- [ ] Add real-time polling (30s interval)
- [ ] Add visual indicators (progress bars, status colors)
- [ ] Add error handling (API failures, missing data)

### Phase 4: Agent Instrumentation
- [ ] Add quota tracking hook to Gemini API handler
- [ ] Add quota tracking hook to GPT handler (if applicable)
- [ ] Add quota tracking hook to Codex handler (if applicable)
- [ ] Add quota tracking hook to CLC handler (if applicable)
- [ ] Test end-to-end: agent request → quota tracked → dashboard updated

### Phase 5: Alerts & Notifications
- [ ] Implement quota warning alerts (80% threshold)
- [ ] Implement quota critical alerts (90% threshold)
- [ ] Add Telegram notifications (if configured)
- [ ] Add dashboard toast notifications

### Phase 6: Testing & Documentation
- [ ] Unit tests for quota tracker
- [ ] Integration tests for API endpoints
- [ ] Manual testing: dashboard widget with real data
- [ ] Update documentation (quota limits, configuration)

---

## 5. Test Strategy

### Unit Tests
- `quota_tracker.py`: Test recording, aggregation, limit checks
- API endpoints: Test response formats, error handling

### Integration Tests
- End-to-end: Agent request → quota tracked → API returns → dashboard displays
- Redis persistence: Verify data survives restarts
- JSONL logging: Verify historical data is logged

### Manual Testing
- Dashboard widget: Visual inspection, real-time updates
- Quota limits: Trigger warnings/critical alerts
- Multiple agents: Verify per-agent tracking works

---

## 6. Risks & Considerations

### Risks
1. **Token counting accuracy:** Some APIs may not return exact token counts
   - **Mitigation:** Use best-effort counting, document limitations

2. **Redis availability:** If Redis is down, quota tracking fails
   - **Mitigation:** Fallback to JSONL-only, graceful degradation

3. **Performance impact:** Tracking every request may add latency
   - **Mitigation:** Async tracking, batch writes, Redis pipelining

4. **Cost estimation:** API pricing may change or be unavailable
   - **Mitigation:** Make cost optional, use estimates if needed

### Considerations
- **Privacy:** Quota data may reveal usage patterns
- **Scalability:** Historical JSONL may grow large (consider rotation)
- **Configuration:** Quota limits should be easily adjustable

---

## 7. Dependencies

- **Existing:**
  - Redis (already in use for pub/sub)
  - Dashboard API server (`api_server.py`)
  - Dashboard UI (`dashboard.js`)

- **New:**
  - None (use existing infrastructure)

---

## 8. Success Criteria

- ✅ Dashboard widget displays real-time quota for all agents
- ✅ Quota tracking works for Gemini API requests
- ✅ API endpoints return accurate quota data
- ✅ Alerts trigger at configured thresholds (80%/90%)
- ✅ Historical data is logged and queryable
- ✅ No performance degradation (<50ms overhead per request)

---

## 9. Next Steps

1. **Review this SPEC** with team (GG, Liam, Andy)
2. **Create PR spec** for implementation (if approved)
3. **Assign to Gemini** via WO (using canonical template)
4. **Implement in phases** (backend → API → dashboard → instrumentation)

---

## 10. Related Documents

- `CONTEXT_ENGINEERING_PROTOCOL_v3.md` (Section: Token Monitoring)
- `GEMINI_CLI_RULES.md` (Quota management)
- Dashboard API documentation (if exists)

---

**Status:** Ready for review and PR creation.
