# Phase 22.1 — Telemetry Dashboard v1 (Interactive Features)

**Status**: Draft Specification
**Depends on**: Phase 22 (v0 Dashboard) merged
**Target**: Enhanced read-only telemetry UI with auto-refresh, filters, and export

---

## 🎯 Objectives

Enhance the Phase 22 static dashboard with **interactive features** while maintaining:
- ✅ No backend dependencies (pure client-side)
- ✅ No CI core workflow changes
- ✅ Zero npm dependencies (vanilla JS)
- ✅ Graceful degradation if features unavailable

---

## 📦 Features

### 1️⃣ Auto-Refresh
**What**: Automatically reload telemetry data every 5-10 seconds

**Implementation**:
```javascript
let autoRefreshInterval = null;
let refreshRate = 10000; // 10 seconds default

function startAutoRefresh() {
  if (autoRefreshInterval) return; // Already running
  autoRefreshInterval = setInterval(load, refreshRate);
  document.querySelector('#auto-refresh-toggle').textContent = '⏸ Pause';
}

function stopAutoRefresh() {
  if (autoRefreshInterval) {
    clearInterval(autoRefreshInterval);
    autoRefreshInterval = null;
  }
  document.querySelector('#auto-refresh-toggle').textContent = '▶ Resume';
}

function toggleAutoRefresh() {
  if (autoRefreshInterval) {
    stopAutoRefresh();
  } else {
    startAutoRefresh();
  }
}
```

**UI Controls**:
- Toggle button: `⏸ Pause` / `▶ Resume` (default: auto-refresh ON)
- Rate selector: 5s / 10s / 30s / 60s
- Visual indicator: "Last updated: 2s ago" (relative time)

**Constraints**:
- Must not refresh if user is actively filtering/viewing
- Use `document.hidden` API to pause when tab inactive
- Preserve scroll position after refresh

---

### 2️⃣ Client-Side Filters
**What**: Filter events by agent, event type, and success status

**Filter Types**:
| Filter | Type | Options |
|--------|------|---------|
| Agent | Dropdown | All, ocr, dispatcher, router, memory_guard, ... |
| Event | Dropdown | All, sha256_validation, file_check, dispatch, ... |
| Status | Radio | All, Success only, Failures only |
| Time Range | Dropdown | All time, Last hour, Last 24h, Last 7 days |

**Implementation**:
```javascript
let filters = {
  agent: 'all',
  event: 'all',
  status: 'all', // 'ok', 'fail'
  timeRange: 'all' // timestamp-based
};

function applyFilters(events) {
  return events.filter(e => {
    if (filters.agent !== 'all' && e.agent !== filters.agent) return false;
    if (filters.event !== 'all' && e.event !== filters.event) return false;
    if (filters.status === 'ok' && !e.ok) return false;
    if (filters.status === 'fail' && e.ok) return false;

    // Time range filtering
    if (filters.timeRange !== 'all') {
      const eventTime = new Date(e.ts);
      const now = new Date();
      const cutoff = now - filters.timeRange; // milliseconds
      if (eventTime < cutoff) return false;
    }

    return true;
  });
}
```

**Dynamic Filter Options**:
- Extract unique agents/events from loaded data
- Update dropdowns dynamically (not hardcoded)
- Show counts: "ocr (42)", "dispatcher (18)"

**UI Layout**:
```
┌─────────────────────────────────────────────┐
│ [Agent ▾] [Event ▾] [Status: ⚪All ●OK ●Fail]│
│ [Time: Last 24h ▾] [Clear Filters]          │
└─────────────────────────────────────────────┘
```

---

### 3️⃣ CSV Export
**What**: Download filtered events as CSV file (client-side only)

**Implementation**:
```javascript
function exportCSV() {
  const data = applyFilters(allEvents); // Use filtered data

  // CSV header
  let csv = 'timestamp,agent,event,ok,detail\n';

  // CSV rows
  for (const row of data) {
    const detail = JSON.stringify(row.detail || {}).replace(/"/g, '""'); // Escape quotes
    csv += `"${row.ts}","${row.agent}","${row.event}",${row.ok},"${detail}"\n`;
  }

  // Trigger download
  const blob = new Blob([csv], { type: 'text/csv' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `telemetry-${Date.now()}.csv`;
  a.click();
  URL.revokeObjectURL(url);
}
```

**UI Button**:
- Position: Top-right corner next to stats
- Icon + text: `⬇ Export CSV (${filteredCount} events)`
- Disabled if no events loaded

---

### 4️⃣ Enhanced Stats Panel
**What**: Show real-time statistics with trend indicators

**Metrics**:
```javascript
{
  total: events.length,
  ok: events.filter(e => e.ok).length,
  fail: events.filter(e => !e.ok).length,
  successRate: (ok / total * 100).toFixed(1), // "95.2%"
  agents: [...new Set(events.map(e => e.agent))].length,
  events: [...new Set(events.map(e => e.event))].length,
  timespan: {
    first: events[0]?.ts,
    last: events[events.length - 1]?.ts
  }
}
```

**UI Layout**:
```
┌──────────────────────────────────────────────────┐
│ 📊 Total: 156  ✅ OK: 148 (94.9%)  ❌ Fail: 8    │
│ 🤖 Agents: 3  ⚡ Events: 5  ⏱ Span: 2h 34m      │
└──────────────────────────────────────────────────┘
```

---

### 5️⃣ Detail Expansion (Optional)
**What**: Click row to expand and show full JSON detail

**Implementation**:
- Each row has `data-id` attribute
- Click handler toggles `.expanded` class
- Insert detail row below main row

**UI**:
```
┌────────────────────────────────────────────┐
│ 2025-11-08 20:47:03 | ocr | sha256 | ✓    │ ← Click
├────────────────────────────────────────────┤
│ {                                          │ ← Expanded
│   "file": "ok_demo.jpg",                   │
│   "sha256": "abc..."                       │
│ }                                          │
└────────────────────────────────────────────┘
```

---

## 🧪 Technical Constraints

### No Backend Changes
- All processing in browser JavaScript
- Read data via fetch (same as v0)
- No server-side filtering/aggregation

### No CI Core Changes
- Reuse `telemetry-ui-check.yml` from Phase 22
- Add sanity check for new JS functions
- No new required checks

### Browser Compatibility
- Target: Modern evergreen browsers (Chrome, Firefox, Safari, Edge)
- Use vanilla JS (ES6+, no transpilation)
- No polyfills needed (assume `fetch`, `URLSearchParams`, `Blob` available)

### File Size Budget
- `telemetry.js`: < 5KB (currently ~1KB → target ~4KB)
- `telemetry.css`: < 2KB (currently ~500B → target ~1.5KB)
- Total: < 7KB for all interactive features

---

## 📊 Success Metrics

| Metric | Target |
|--------|--------|
| Load time | < 200ms (including JSON fetch) |
| Filter response | < 50ms (for 1000 events) |
| CSV export | < 500ms (for 1000 events) |
| Memory usage | < 10MB (for 10,000 events) |

---

## 🚀 Implementation Plan

### Phase 22.1a: Auto-Refresh Only
**Files**:
- `hub/ui/telemetry.js` — Add auto-refresh logic
- `hub/ui/telemetry.html` — Add toggle button + rate selector
- `hub/ui/telemetry.css` — Style controls

**Effort**: ~30 minutes
**Risk**: Low (isolated feature)

### Phase 22.1b: Filters + CSV Export
**Files**:
- `hub/ui/telemetry.js` — Add filter logic + CSV export
- `hub/ui/telemetry.html` — Add filter UI + export button
- `hub/ui/telemetry.css` — Style filter row

**Effort**: ~60 minutes
**Risk**: Medium (more complex state management)

### Phase 22.1c: Enhanced Stats
**Files**:
- `hub/ui/telemetry.js` — Calculate extended stats
- `hub/ui/telemetry.html` — Update stats layout
- `hub/ui/telemetry.css` — Style multi-line stats

**Effort**: ~20 minutes
**Risk**: Low (just display logic)

**Total Effort**: ~2 hours
**Recommended Approach**: Ship all features together (22.1 as single PR)

---

## 🔍 Testing Strategy

### Manual Testing
```bash
# 1. Generate diverse fixture data
./tools/telemetry_fixture.zsh

# Add more events from different agents
./tools/telemetry_unified.zsh dispatcher route_event true '{"route":"ocr","priority":"high"}'
./tools/telemetry_unified.zsh memory_guard size_check false '{"file":"huge.bin","size_mb":30}'
./tools/telemetry_unified.zsh router health_check true '{}'

# 2. Start server
./tools/hub_http.zsh

# 3. Open dashboard
open http://localhost:8080/ui/telemetry.html

# 4. Test scenarios:
# ✓ Auto-refresh toggles (observe network tab)
# ✓ Filter by agent (select "ocr")
# ✓ Filter by status (select "Failures only")
# ✓ Export CSV (check downloaded file)
# ✓ Clear filters (all events visible again)
```

### Automated CI Check
```yaml
# .github/workflows/telemetry-ui-check.yml (enhanced)
- name: Validate JS has required functions
  run: |
    grep -q 'startAutoRefresh' hub/ui/telemetry.js
    grep -q 'applyFilters' hub/ui/telemetry.js
    grep -q 'exportCSV' hub/ui/telemetry.js
```

---

## 📋 Acceptance Criteria

- [ ] Auto-refresh works (default: ON, 10s interval)
- [ ] Auto-refresh pauses when tab hidden
- [ ] Filters update dynamically based on loaded events
- [ ] Multiple filters can be combined (AND logic)
- [ ] CSV export includes only filtered events
- [ ] CSV filename includes timestamp
- [ ] Stats panel shows success rate percentage
- [ ] All features work with 0 events (graceful empty state)
- [ ] All features work with 10,000+ events (performance)
- [ ] No console errors in browser
- [ ] File size budget met (< 7KB total)

---

## 🔗 Related

- **Depends on**: Phase 22 (v0 Dashboard) — must be merged first
- **Builds on**: PR #248 (Unified Telemetry API)
- **Foundation for**: Phase 22.2 (Alerting thresholds & notifications)

---

## 💡 Future Enhancements (Phase 22.2+)

- **Search**: Full-text search across detail JSON
- **Sorting**: Click column headers to sort
- **Pagination**: Show 50/100/500 events per page
- **Charts**: Sparklines for success rate over time
- **Alerts**: Visual indicators when failure rate > threshold
- **Websockets**: Real-time push instead of polling
- **Dark mode**: Toggle light/dark theme

---

**Generated**: 2025-11-08
**Status**: Ready for implementation (awaiting Phase 22 v0 merge)
