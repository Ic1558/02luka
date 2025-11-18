# PR #349 Conflict Analysis

**Date:** 2025-11-18  
**PR:** [#349 - Add WO timeline/history view to dashboard](https://github.com/Ic1558/02luka/pull/349)  
**Status:** Analyzing conflicts

---

## PR Information

**Details:**
- Number: #349
- Title: Add WO timeline/history view to dashboard
- State: OPEN
- Head Branch: `codex/add-work-order-timeline/history-view`
- Base Branch: main

**Feature:** Adds Work Order timeline/history view to dashboard with new API endpoint

---

## Conflict Analysis

### Merge Test Result

**Status:** Automatic merge went well (no conflicts detected in test)

**However:** PR shows CONFLICTING status, likely due to:
- Dashboard files may have conflicts (dashboard.js, index.html)
- API server routing may need adjustment

### Files Changed in PR

1. `apps/dashboard/dashboard.js` - Timeline UI logic
2. `apps/dashboard/index.html` - Timeline view HTML
3. `apps/dashboard/wo_dashboard_server.py` - Server updates
4. `g/apps/dashboard/api_server.py` - New `/api/wos/history` endpoint
5. `g/apps/dashboard/dashboard.js` - Timeline UI (g/ version)
6. `g/apps/dashboard/index.html` - Timeline HTML (g/ version)
7. `g/reports/feature_wo_timeline_20251115.md` - Documentation

### Potential Conflicts

**Dashboard Files:**
- `dashboard.js` - Main has v2.2.0 features, PR adds timeline
- `index.html` - Main has updated structure, PR adds timeline view

**API Server:**
- Main doesn't have `/api/wos/history` endpoint
- PR adds new endpoint and handler
- Need to ensure routing order is correct

---

## Code Review Finding

**From PR #349 review:** P1 Badge - Route `/api/wos/history` before prefix match

**Issue:** The endpoint routing order was incorrect:
- Original: `/api/wos/:id` handler checked before `/api/wos/history`
- Problem: `/api/wos/history` matched the prefix and routed to `handle_get_wo('history', ...)`
- Fix: Check exact `/api/wos/history` path before the generic `/api/wos/:id` handler

**Status:** According to PR commits, this was already fixed in commit `21f9852`

**Current Main Routing (lines 267-271):**
```python
if path == '/api/wos':
    self.handle_list_wos(query)
elif path.startswith('/api/wos/'):
    wo_id = path.split('/')[-1]
    self.handle_get_wo(wo_id, query)
```

**PR Should Have:**
```python
if path == '/api/wos':
    self.handle_list_wos(query)
elif path == '/api/wos/history':  # Check exact path first
    self.handle_list_wos_history(query)
elif path.startswith('/api/wos/'):  # Then generic handler
    wo_id = path.split('/')[-1]
    self.handle_get_wo(wo_id, query)
```

---

## Resolution Strategy

### Step 1: Verify Routing Order

Check if PR has correct routing order (should be fixed already).

### Step 2: Resolve Dashboard Conflicts

**Dashboard.js:**
- Accept main version as base (v2.2.0)
- Add PR #349 timeline functions
- Integrate timeline into existing dashboard

**Index.html:**
- Accept main version as base
- Add PR #349 timeline view HTML
- Ensure timeline tab works with existing tabs

### Step 3: API Server Integration

- Add `/api/wos/history` endpoint
- Ensure routing order is correct (history before generic)
- Add `handle_list_wos_history()` function

---

## Next Steps

1. ⏳ Check actual conflicts (if any)
2. ⏳ Verify routing fix is in PR
3. ⏳ Resolve dashboard conflicts (if any)
4. ⏳ Test timeline functionality
5. ⏳ Push fixes to PR branch

---

**Status:** Ready for conflict resolution  
**Confidence:** High (routing issue already fixed in PR)  
**Estimated Time:** 30-45 min

