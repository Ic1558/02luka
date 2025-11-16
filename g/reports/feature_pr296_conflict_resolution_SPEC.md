# PR #296 Conflict Resolution - SPEC

**Date:** 2025-11-16  
**Feature:** Resolve merge conflict between PR #296 and routing fix  
**Status:** 🟡 **SPECIFICATION**

---

## Problem Statement

PR #296 (`codex/add-wo-pipeline-metrics-to-dashboard`) has merge conflicts with `main` branch, specifically in `g/apps/dashboard/api_server.py`. The conflict occurs because:

1. **PR #296** adds:
   - New `/api/wo-metrics` endpoint
   - `handle_wo_metrics()` method
   - Additional imports (`Counter`, `timezone`)

2. **Main branch** (via `fix/wo-history-endpoint`) has:
   - Fixed routing order: `/api/wos/history` checked BEFORE `/api/wos/` prefix
   - New `handle_list_wos_history()` method

3. **Conflict:** Both modify the same routing section in `do_GET()` method

---

## Current State Analysis

### PR #296 Branch (`codex/add-wo-pipeline-metrics-to-dashboard`)
```python
# Routing (WRONG - missing history fix):
if path == '/api/wos':
    self.handle_list_wos(query)
elif path.startswith('/api/wos/'):  # ❌ Would catch /api/wos/history incorrectly
    wo_id = path.split('/')[-1]
    self.handle_get_wo(wo_id, query)
elif path == '/api/services':
    self.handle_list_services(query)
elif path == '/api/wo-metrics':  # ✅ New endpoint
    self.handle_wo_metrics(query)
```

### Main Branch (with routing fix)
```python
# Routing (CORRECT):
if path == '/api/wos':
    self.handle_list_wos(query)
elif path == '/api/wos/history':  # ✅ Fixed: checked first
    self.handle_list_wos_history(query)
elif path.startswith('/api/wos/'):  # ✅ Fixed: checked after history
    wo_id = path.split('/')[-1]
    self.handle_get_wo(wo_id, query)
elif path == '/api/services':
    self.handle_list_services(query)
# ❌ Missing: /api/wo-metrics endpoint
```

---

## Requirements

### Functional Requirements

1. **Preserve Routing Fix**
   - `/api/wos/history` must be checked BEFORE `/api/wos/` prefix match
   - `handle_list_wos_history()` method must be present

2. **Preserve PR #296 Features**
   - `/api/wo-metrics` endpoint must be added
   - `handle_wo_metrics()` method must be present
   - Required imports (`Counter`, `timezone`) must be added

3. **Maintain Code Quality**
   - No duplicate code
   - Proper endpoint ordering (specific before generic)
   - All endpoints functional

### Non-Functional Requirements

1. **Backward Compatibility**
   - Existing endpoints must continue to work
   - No breaking changes to API contracts

2. **Testing**
   - All endpoints must be testable
   - Routing logic must be verified

---

## Solution Approach

### Strategy: Merge Both Changes

**Resolution Steps:**
1. Start from PR #296 branch
2. Apply routing fix from `main` branch
3. Ensure both features coexist
4. Verify endpoint ordering

### Expected Final State

```python
# Correct routing order:
if path == '/api/wos':
    self.handle_list_wos(query)
elif path == '/api/wos/history':  # ✅ From main (fix)
    self.handle_list_wos_history(query)
elif path.startswith('/api/wos/'):  # ✅ From main (fix)
    wo_id = path.split('/')[-1]
    self.handle_get_wo(wo_id, query)
elif path == '/api/services':
    self.handle_list_services(query)
elif path == '/api/wo-metrics':  # ✅ From PR #296
    self.handle_wo_metrics(query)
elif path == '/api/mls':
    self.handle_list_mls(query)
elif path == '/api/health/logs':
    self.handle_get_logs(query)
```

---

## Success Criteria

1. ✅ PR #296 merges cleanly into `main`
2. ✅ `/api/wos/history` endpoint works correctly
3. ✅ `/api/wo-metrics` endpoint works correctly
4. ✅ All existing endpoints continue to work
5. ✅ No routing conflicts (specific paths checked before generic)
6. ✅ Code passes linting/validation

---

## Risk Assessment

**Low Risk:**
- Both changes are additive (new endpoints, new methods)
- No breaking changes to existing functionality
- Clear merge path (combine both features)

**Mitigation:**
- Test all endpoints after merge
- Verify routing order with integration tests
- Review code for any edge cases

---

## Dependencies

- PR #296 branch: `codex/add-wo-pipeline-metrics-to-dashboard`
- Main branch: Contains routing fix
- Both branches must be up-to-date

---

## Out of Scope

- Modifying PR #296's metrics implementation
- Changing routing logic beyond fixing the order
- Refactoring other parts of `api_server.py`

---

**Next Step:** Create detailed PLAN.md with task breakdown
