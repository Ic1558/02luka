# PR #310 Cleanup Plan

**Date:** 2025-11-17  
**PR:** #310 - Add WO timeline/history view in dashboard  
**Status:** ⚠️ Non-blocking issues to address

---

## Governance Review Summary

**Overall Score:** 7.9/10  
**Verdict:** ⚠️ **REQUEST CHANGES** (Non-blocking - core feature approved)

**Core Feature:** ✅ **APPROVED** - WO timeline implementation is solid

---

## Non-Blocking Issues to Address

### 1. Remove Unrelated Files ⚠️

**Files to Remove:**
- `LaunchAgents/com.02luka.agent.health.plist` - Monitoring, not WO timeline
- `LaunchAgents/com.02luka.alert.router.plist` - Monitoring, not WO timeline  
- `LaunchAgents/com.02luka.process.watchdog.plist` - Monitoring, not WO timeline
- `tools/workerctl.zsh` - Worker verification, not WO timeline
- `tools/protect_critical_files.zsh` - File protection, not WO timeline
- `g/reports/system/ANDY_FINAL_REVIEW.md` - Review doc, not feature code
- `g/reports/system/ANDY_SMART_REVIEW_PHASE1.md` - Review doc, not feature code

**Files to Clarify:**
- Duplicate dashboard files: `apps/dashboard/` vs `g/apps/dashboard/`
  - Need to determine canonical location
  - Remove duplicates or document which is authoritative

### 2. Add API Documentation ⚠️

**Missing:**
- API endpoint documentation for `/api/wos/:id?timeline=1`
- Parameter documentation (`timeline=1`, `tail=N`)
- Response format documentation
- Timeline structure documentation

**Action:**
- Add docstring to `handle_get_wo()` method
- Document timeline parameter and response format
- Add to API documentation file or README

### 3. Improve Log Parsing Robustness ⚠️

**Current:**
- Log parsing may not handle all edge cases
- Error handling could be more robust

**Action:**
- Review log parsing logic in `_build_wo_timeline()` or similar
- Add error handling for malformed logs
- Add validation for log tail parsing

---

## Cleanup Steps

### Step 1: Remove Unrelated Files

```bash
cd /Users/icmini/02luka
git checkout codex/add-wo-timeline-and-history-view

# Remove unrelated files
git rm LaunchAgents/com.02luka.agent.health.plist
git rm LaunchAgents/com.02luka.alert.router.plist
git rm LaunchAgents/com.02luka.process.watchdog.plist
git rm tools/workerctl.zsh
git rm tools/protect_critical_files.zsh
git rm g/reports/system/ANDY_FINAL_REVIEW.md
git rm g/reports/system/ANDY_SMART_REVIEW_PHASE1.md
```

### Step 2: Resolve Duplicate Dashboard Files

**Decision needed:**
- Which is canonical: `apps/dashboard/` or `g/apps/dashboard/`?
- Based on 02luka structure guidelines, `g/apps/dashboard/` is likely canonical
- Remove `apps/dashboard/` files or document why both exist

### Step 3: Add API Documentation

Add to `g/apps/dashboard/api_server.py`:

```python
def handle_get_wo(self, wo_id, query):
    """
    Handle GET /api/wos/:id - get WO details
    
    Query Parameters:
        tail (int): Number of log lines to include (default: none)
        timeline (int): Include timeline events (1 = yes, default: no)
    
    Response:
        {
            "id": "WO-123",
            "status": "complete",
            "timeline": [  # Only if timeline=1
                {
                    "timestamp": "2025-11-17T10:00:00",
                    "event": "created",
                    "message": "Work order created"
                },
                ...
            ],
            "log_tail": [...]  # Only if tail parameter provided
        }
    """
```

### Step 4: Improve Log Parsing

Review and enhance log parsing in timeline builder:
- Add try/except blocks
- Validate log format
- Handle edge cases (empty logs, malformed entries)

---

## After Cleanup

Once cleanup is complete:
1. ✅ Core feature remains (WO timeline)
2. ✅ Unrelated files removed
3. ✅ API documented
4. ✅ Log parsing improved
5. ✅ Ready for merge

---

## Files to Keep

**Core Feature Files:**
- `g/apps/dashboard/api_server.py` (with timeline support)
- `g/apps/dashboard/dashboard.js` (timeline UI)
- `g/apps/dashboard/index.html` (timeline UI)
- `g/apps/dashboard/data/followup.json` (if needed)

**Documentation:**
- `reports/ci/CI_RELIABILITY_PACK.md` (if related to PR)

---

**Next Step:** Execute cleanup steps above
