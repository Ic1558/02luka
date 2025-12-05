# Code Review: 02luka_gateway.py

**Reviewer:** CLS  
**Date:** 2025-12-05  
**File:** `02luka_gateway.py`  
**Lines:** 368  
**Status:** ⚠️ **APPROVE WITH FIXES**

---

## 📋 **EXECUTIVE SUMMARY**

The gateway implementation follows the pattern of `agent_listener.py` but has several issues that need addressing:
- ✅ Good: Structure, error handling, logging
- ⚠️ Missing: Safety checks (CloudStorage blocking), path validation
- ⚠️ Issue: Hardcoded Redis password in code (security risk)
- ⚠️ Issue: Missing shutdown handling in redis-cli loop
- ⚠️ Issue: Duplicate code in main() (redispy vs cli branches)

**Verdict:** ⚠️ **APPROVE WITH FIXES** - Needs safety checks and code deduplication before production.

---

## 🔍 **DETAILED FINDINGS**

### **1. CRITICAL: Missing Safety Checks** ⚠️

**Issue:** `agent_listener.py` has `assert_local_blob()` function that blocks CloudStorage paths, but `02luka_gateway.py` doesn't have this.

**Location:** Missing entirely

**Risk:** HIGH - Could allow commands that access CloudStorage paths, violating system safety rules.

**Fix Required:**
```python
# Add after line 33 (imports section)
import re

# Add after line 64 (before Redis Client section)
def assert_local_blob(s: str):
    """Block CloudStorage paths"""
    if not s:
        return
    if re.search(r"Library/CloudStorage|My Drive/02luka", s):
        raise RuntimeError("Blocked non-local CloudStorage path found in payload")

# Add in run_router() function (line 194, before router execution):
assert_local_blob(json.dumps(task_json, ensure_ascii=False))
```

---

### **2. SECURITY: Hardcoded Password** ⚠️

**Issue:** Line 49 has hardcoded Redis password `"gggclukaic"` as default.

**Location:** Line 49
```python
REDIS_PASS = os.getenv("REDIS_PASSWORD", "gggclukaic")  # From .cursorrules
```

**Risk:** MEDIUM - Password visible in code. While it's in `.cursorrules`, it's better to require env var.

**Fix Required:**
```python
REDIS_PASS = os.getenv("REDIS_PASSWORD")
if not REDIS_PASS:
    safe_log("⚠️  REDIS_PASSWORD not set, connection may fail", "WARN")
```

**Note:** Check if password is actually in `.env.local` - if so, should load from there.

---

### **3. CODE DUPLICATION: Main Loop** ⚠️

**Issue:** Lines 276-316 and 321-356 are nearly identical - duplicate message processing logic.

**Location:** `main()` function

**Risk:** LOW - Maintenance burden, but functionally works.

**Fix Required:** Extract common logic to a function:
```python
def process_message(ch: str, raw: str, client_or_none, mode: str):
    """Process a single message from any channel"""
    task = normalize_message(ch, raw)
    task_id = task.get("task_id") or f"gw_{int(time.time() * 1000)}"
    
    safe_log(f"📥 Received command from {ch}: {task.get('intent', 'unknown')}", "INFO")
    
    # Write receipt
    write_json(RECEIPTS / f"{task_id}.json", {
        "channel": ch,
        "received_at": datetime.now(timezone.utc).isoformat(),
        "task": task
    })
    
    # Execute via router
    res = run_router(task, task_id)
    
    # Write result
    write_json(RESULTS / f"{task_id}.json", {
        "channel": ch,
        "completed_at": datetime.now(timezone.utc).isoformat(),
        "result": res
    })
    
    # Publish result back
    result_channel = f"{ch}.result"
    if mode == "redispy" and client_or_none:
        client_or_none.publish(result_channel, json.dumps(res, ensure_ascii=False))
    else:
        cli_pub(result_channel, json.dumps(res, ensure_ascii=False))
    
    status = "✅" if res.get("ok") else "❌"
    safe_log(f"{status} {task_id} completed (ch={ch}, ok={res.get('ok')})", "INFO")
    
    return res
```

Then use in both branches.

---

### **4. SHUTDOWN HANDLING: Redis-CLI Loop** ⚠️

**Issue:** In `cli_subscribe_loop()`, the `proc.terminate()` is called but process cleanup isn't guaranteed.

**Location:** Line 151

**Risk:** LOW - Process may not terminate cleanly.

**Fix Required:**
```python
if shutdown_flag:
    proc.terminate()
    try:
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        proc.kill()
    break
```

---

### **5. PATH CONFIGURATION: LUKA_HOME Default** ⚠️

**Issue:** Line 36 uses `PROJECT_ROOT / "g"` but `agent_listener.py` uses `~/LocalProjects/02luka_local_g/g` (legacy path).

**Location:** Line 36

**Risk:** LOW - Should align with current SOT path.

**Current:**
```python
LUKA_HOME = Path(os.getenv("LUKA_HOME", PROJECT_ROOT / "g"))
```

**Should be:** (matches .cursorrules)
```python
LUKA_HOME = Path(os.getenv("LUKA_HOME", os.path.expanduser("~/02luka/g")))
```

---

### **6. ROUTER PATH: Should Use LUKA_HOME** ⚠️

**Issue:** Line 63 uses `PROJECT_ROOT / "agent_router.py"` but should check `LUKA_HOME` first (like `agent_listener.py` does).

**Location:** Line 63

**Current:**
```python
ROUTER = PROJECT_ROOT / "agent_router.py"
```

**Should be:**
```python
ROUTER = LUKA_HOME / "agent_router.py"
if not ROUTER.exists():
    ROUTER = PROJECT_ROOT / "agent_router.py"  # Fallback
```

---

### **7. LOGGING: Timestamp Format Inconsistency** ℹ️

**Issue:** `agent_listener.py` uses `datetime.now().isoformat()` (no timezone), gateway uses `datetime.now(timezone.utc).isoformat()` (UTC).

**Location:** Line 72

**Risk:** LOW - UTC is better, but creates inconsistency with existing logs.

**Recommendation:** Keep UTC (it's better), but note the difference.

---

### **8. CHANNEL OVERLAP: Potential Conflict** ⚠️

**Issue:** `02luka_gateway.py` listens to channels that `agent_listener.py` also listens to:
- `telegram:agent` (both)
- `kim:agent` (both)
- `gg:agent_router` (both)

**Location:** Lines 53-60

**Risk:** MEDIUM - Both listeners will process the same messages, causing duplicate execution.

**Fix Required:** Either:
1. Remove overlapping channels from one listener
2. Use different channel names
3. Document which listener handles which channels

**Recommendation:** Since `agent_listener.py` already exists and is operational, `02luka_gateway.py` should use different channels OR replace `agent_listener.py` entirely.

---

### **9. MISSING: Error Recovery** ℹ️

**Issue:** If Redis connection fails completely, the gateway exits. `agent_listener.py` has better fallback handling.

**Location:** `build_redis_client()`

**Risk:** LOW - Fallback exists, but could be more robust.

**Current:** Returns `("cli", None)` on failure  
**Status:** Acceptable, but could add retry logic.

---

### **10. MISSING: Receipt/Result Schema Validation** ℹ️

**Issue:** No validation that receipts/results follow expected schema.

**Location:** `write_json()` calls

**Risk:** LOW - JSON is flexible, but schema validation would catch issues early.

**Recommendation:** Optional enhancement for future.

---

## ✅ **POSITIVE ASPECTS**

1. **Good Structure:** Well-organized with clear sections
2. **Error Handling:** Comprehensive try/except blocks
3. **Logging:** Detailed logging with timestamps and levels
4. **Graceful Shutdown:** Signal handlers implemented
5. **Atomic File Writes:** Uses tmp file + replace pattern
6. **Type Hints:** Uses typing annotations
7. **Documentation:** Good docstrings
8. **UTC Timestamps:** Better than local time for logs

---

## 🔧 **REQUIRED FIXES (Before Production)**

### **Priority 1 (Critical):**
1. ✅ Add `assert_local_blob()` safety check
2. ✅ Fix hardcoded password (require env var or load from .env.local)
3. ✅ Resolve channel overlap with `agent_listener.py`

### **Priority 2 (Important):**
4. ✅ Deduplicate main loop code
5. ✅ Fix router path to use LUKA_HOME
6. ✅ Improve shutdown handling in cli_subscribe_loop

### **Priority 3 (Nice to Have):**
7. ⚠️ Add retry logic for Redis connection
8. ⚠️ Add schema validation for receipts/results
9. ⚠️ Add health check endpoint (if running as service)

---

## 📊 **RISK ASSESSMENT**

| Risk | Level | Impact | Mitigation |
|------|-------|--------|------------|
| Missing safety checks | HIGH | Could allow unsafe paths | Add `assert_local_blob()` |
| Channel overlap | MEDIUM | Duplicate execution | Use different channels or replace listener |
| Hardcoded password | MEDIUM | Security exposure | Require env var |
| Code duplication | LOW | Maintenance burden | Refactor to shared function |
| Path configuration | LOW | May not find router | Use LUKA_HOME first |

---

## 🎯 **RECOMMENDATIONS**

### **Immediate Actions:**
1. Add safety checks before production use
2. Resolve channel overlap (decide: replace `agent_listener.py` or use different channels)
3. Remove hardcoded password

### **Architecture Decision Needed:**
**Question:** Is `02luka_gateway.py` meant to:
- **A)** Replace `agent_listener.py`? (Then remove old one)
- **B)** Complement `agent_listener.py`? (Then use different channels)
- **C)** Be an alternative implementation? (Then document when to use which)

**Current State:** Both files exist and would conflict if both run simultaneously.

---

## 📝 **CODE QUALITY METRICS**

- **Lines of Code:** 368
- **Functions:** 8
- **Cyclomatic Complexity:** Medium (main loop has branching)
- **Test Coverage:** 0% (no tests found)
- **Documentation:** Good (docstrings present)
- **Type Hints:** Partial (some functions have hints)

---

## ✅ **FINAL VERDICT**

**Status:** ⚠️ **APPROVE WITH FIXES**

**Reasoning:**
- Code structure is sound
- Follows existing patterns well
- Missing critical safety checks
- Channel overlap needs resolution
- Security concern with hardcoded password

**Blockers for Production:**
1. Add `assert_local_blob()` safety check
2. Resolve channel overlap with `agent_listener.py`
3. Remove hardcoded password

**Estimated Fix Time:** 30-60 minutes

---

**End of Review**
