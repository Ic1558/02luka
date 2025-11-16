# PR #296 Conflict Resolution - PLAN

**Date:** 2025-11-16  
**Feature:** Resolve merge conflict between PR #296 and routing fix  
**Status:** 🟢 **PLAN**

---

## Overview

Resolve merge conflict in PR #296 by merging the routing fix from `main` branch while preserving PR #296's new `/api/wo-metrics` endpoint.

**Estimated Time:** 30-45 minutes  
**Complexity:** Low (additive changes, clear merge path)

---

## Task Breakdown

### Task 1: Prepare Working Environment
**Time:** 5 minutes  
**Status:** ⏳ Pending

**Actions:**
1. Stash current changes (if any)
2. Fetch latest from origin
3. Checkout PR #296 branch: `codex/add-wo-pipeline-metrics-to-dashboard`
4. Verify branch is up-to-date with base

**Commands:**
```bash
cd /Users/icmini/02luka
git stash  # If needed
git fetch origin
git checkout codex/add-wo-pipeline-metrics-to-dashboard
git pull origin codex/add-wo-pipeline-metrics-to-dashboard
```

**Verification:**
- Branch checked out successfully
- No uncommitted changes
- Branch is clean

---

### Task 2: Merge Routing Fix from Main
**Time:** 10 minutes  
**Status:** ⏳ Pending

**Actions:**
1. Identify routing fix changes from `main` branch
2. Apply routing fix to PR #296 branch
3. Ensure `/api/wos/history` is checked before `/api/wos/` prefix
4. Add `handle_list_wos_history()` method if missing

**Changes to Apply:**
```python
# In do_GET() method, update routing:
if path == '/api/wos':
    self.handle_list_wos(query)
elif path == '/api/wos/history':  # ADD: Check before prefix
    self.handle_list_wos_history(query)
elif path.startswith('/api/wos/'):  # MOVE: After history check
    wo_id = path.split('/')[-1]
    self.handle_get_wo(wo_id, query)
# ... rest of routing ...
elif path == '/api/wo-metrics':  # KEEP: From PR #296
    self.handle_wo_metrics(query)
```

**Verification:**
- Routing order is correct
- `handle_list_wos_history()` method exists
- No duplicate code

---

### Task 3: Verify All Endpoints Present
**Time:** 5 minutes  
**Status:** ⏳ Pending

**Actions:**
1. Check all required endpoints are present:
   - `/api/wos` ✅
   - `/api/wos/history` ✅ (from main fix)
   - `/api/wos/:id` ✅
   - `/api/services` ✅
   - `/api/wo-metrics` ✅ (from PR #296)
   - `/api/mls` ✅
   - `/api/health/logs` ✅

2. Verify all handler methods exist:
   - `handle_list_wos()` ✅
   - `handle_list_wos_history()` ✅ (from main fix)
   - `handle_get_wo()` ✅
   - `handle_list_services()` ✅
   - `handle_wo_metrics()` ✅ (from PR #296)
   - `handle_list_mls()` ✅
   - `handle_get_logs()` ✅

**Verification:**
- All endpoints listed above are present
- All handler methods exist
- No missing imports

---

### Task 4: Test Routing Logic
**Time:** 10 minutes  
**Status:** ⏳ Pending

**Test Strategy:**

**Unit Tests (Manual):**
1. Test `/api/wos/history` routing:
   ```bash
   curl http://localhost:8080/api/wos/history
   # Should route to handle_list_wos_history(), not handle_get_wo('history')
   ```

2. Test `/api/wo-metrics` routing:
   ```bash
   curl http://localhost:8080/api/wo-metrics
   # Should route to handle_wo_metrics()
   ```

3. Test `/api/wos/:id` routing:
   ```bash
   curl http://localhost:8080/api/wos/WO-123
   # Should route to handle_get_wo('WO-123')
   ```

4. Test routing order:
   - `/api/wos/history` should NOT match `/api/wos/` prefix first
   - Specific paths checked before generic patterns

**Integration Tests:**
- Start dashboard server
- Test all endpoints via HTTP requests
- Verify responses are correct
- Check for 404 errors (should not occur)

**Verification:**
- All routing tests pass
- No 404 errors for valid endpoints
- Correct handlers called for each path

---

### Task 5: Resolve Merge Conflict
**Time:** 10 minutes  
**Status:** ⏳ Pending

**Actions:**
1. Attempt merge from `main`:
   ```bash
   git merge origin/main
   ```

2. If conflicts occur:
   - Open `g/apps/dashboard/api_server.py`
   - Resolve conflict markers
   - Keep both features (routing fix + metrics endpoint)
   - Remove conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`)

3. Stage resolved file:
   ```bash
   git add g/apps/dashboard/api_server.py
   ```

4. Complete merge:
   ```bash
   git commit -m "merge: Resolve conflict with main - preserve routing fix and metrics endpoint"
   ```

**Conflict Resolution Strategy:**
- **Keep:** Routing fix from main (history endpoint order)
- **Keep:** Metrics endpoint from PR #296
- **Merge:** Both changes into single routing block
- **Order:** Specific paths before generic patterns

**Verification:**
- No conflict markers in file
- Both features present
- Code compiles/runs without errors

---

### Task 6: Push and Verify PR Status
**Time:** 5 minutes  
**Status:** ⏳ Pending

**Actions:**
1. Push resolved branch:
   ```bash
   git push origin codex/add-wo-pipeline-metrics-to-dashboard
   ```

2. Check PR status:
   ```bash
   gh pr view 296 --repo Ic1558/02luka --json mergeable,mergeStateStatus
   ```

3. Verify conflict resolved:
   - PR should show `mergeable: true`
   - PR should show `mergeStateStatus: CLEAN` or `BEHIND`

**Verification:**
- Branch pushed successfully
- PR shows no conflicts
- PR is ready for review/merge

---

## Test Strategy

### Test Coverage

**1. Routing Tests:**
- ✅ `/api/wos/history` routes correctly
- ✅ `/api/wo-metrics` routes correctly
- ✅ `/api/wos/:id` routes correctly
- ✅ Routing order is correct (specific before generic)

**2. Endpoint Tests:**
- ✅ All endpoints return valid responses
- ✅ No 404 errors for valid paths
- ✅ CORS headers present

**3. Integration Tests:**
- ✅ Dashboard server starts successfully
- ✅ All API endpoints accessible
- ✅ Frontend can consume all endpoints

### Test Execution

**Manual Testing:**
```bash
# Start dashboard server
cd /Users/icmini/02luka/g/apps/dashboard
python3 api_server.py &

# Test endpoints
curl http://localhost:8080/api/wos/history
curl http://localhost:8080/api/wo-metrics
curl http://localhost:8080/api/wos
curl http://localhost:8080/api/wos/WO-123

# Stop server
pkill -f api_server.py
```

**Automated Testing:**
- Create test script: `tools/test_pr296_resolution.zsh`
- Test all endpoints
- Verify responses
- Report results

---

## Rollback Plan

If resolution fails or introduces issues:

1. **Abort Merge:**
   ```bash
   git merge --abort
   ```

2. **Reset Branch:**
   ```bash
   git reset --hard origin/codex/add-wo-pipeline-metrics-to-dashboard
   ```

3. **Alternative Approach:**
   - Create new branch from `main`
   - Cherry-pick PR #296 commits
   - Apply routing fix
   - Create new PR

---

## Success Criteria

✅ **All Tasks Complete:**
- Task 1: Environment prepared
- Task 2: Routing fix merged
- Task 3: All endpoints verified
- Task 4: Routing tests pass
- Task 5: Conflict resolved
- Task 6: PR status verified

✅ **Functional Requirements Met:**
- `/api/wos/history` works correctly
- `/api/wo-metrics` works correctly
- All existing endpoints work
- No routing conflicts

✅ **Quality Requirements Met:**
- Code is clean (no conflict markers)
- Routing order is correct
- All tests pass
- PR is mergeable

---

## Next Steps After Completion

1. **Request Review:**
   - PR #296 is ready for review
   - All conflicts resolved
   - Both features working

2. **Monitor PR:**
   - Wait for CI checks
   - Address any review comments
   - Merge when approved

3. **Documentation:**
   - Update API documentation if needed
   - Document new `/api/wo-metrics` endpoint
   - Document routing fix

---

## Notes

- **Low Risk:** Both changes are additive, no breaking changes
- **Clear Path:** Simple merge of two features
- **Quick Resolution:** Estimated 30-45 minutes total
- **No Dependencies:** Can be done independently

---

**Status:** 🟢 **READY TO EXECUTE**
