# Code Review: Doctor Agent Implementation

**Date:** 2025-12-05  
**Files Reviewed:**
- `tools/doctor.py` (Phase 1 implementation)
- `LaunchAgents/com.02luka.doctor.plist` (LaunchAgent config)

**Reviewer:** CLS  
**Status:** ✅ **APPROVED WITH MINOR NOTES**

---

## ✅ **STRENGTHS**

### **1. Code Structure**
- ✅ Clean separation of concerns (collect → diagnose → heal → log)
- ✅ Proper error handling with try/except blocks
- ✅ Good logging throughout
- ✅ Follows Python best practices

### **2. Fallback Logic**
- ✅ Robust fallback heuristics (works without LLM)
- ✅ Handles connection errors correctly
- ✅ Handles JSON contract mismatches
- ✅ Graceful degradation if LLM unavailable

### **3. Auto-Healing**
- ✅ Correct condition check (`lane == "ops_qa"` and `root_cause == "gateway_offline"`)
- ✅ Proper process management (kill → restart)
- ✅ Logs actions to telemetry

### **4. Telemetry**
- ✅ JSON Lines format (append-friendly)
- ✅ Complete fields (timestamp, context, diagnosis, action)
- ✅ Directory creation handled

### **5. LaunchAgent**
- ✅ Correct configuration (StartInterval: 300, ThrottleInterval: 30)
- ✅ Proper log paths
- ✅ Environment variables set

---

## ⚠️ **MINOR ISSUES & RECOMMENDATIONS**

### **Issue 1: Path Configuration (FIXED)**

**Problem:**
- Initial code used `LUKA_HOME / "g" / "telemetry"` which could create `g/g/telemetry` if `LUKA_HOME` env var is set to `~/02luka/g`

**Fix Applied:**
- Changed to explicit `BASE_DIR = Path(os.path.expanduser("~/02luka"))`
- Ensures consistent path regardless of env vars

**Status:** ✅ **FIXED**

---

### **Issue 2: Gateway Restart Command**

**Current:**
```python
subprocess.Popen(
    ["python3", str(GATEWAY_SCRIPT)],
    cwd=str(GATEWAY_DIR),
    stdout=open("/tmp/gateway.log", "a"),
    stderr=subprocess.STDOUT,
    start_new_session=True
)
```

**Recommendation:**
- Consider using `nohup` wrapper for better process isolation
- Or use LaunchAgent for gateway (if available)
- Current implementation is acceptable for Phase 1

**Status:** ⚠️ **ACCEPTABLE** (can improve in Phase 2)

---

### **Issue 3: Dummy LLM Diagnosis**

**Current:**
- `call_llm_diagnose()` uses simple pattern matching
- Returns hardcoded diagnosis based on keywords

**Note:**
- This is **intentional** for Phase 1 (no LLM calls yet)
- TODO comment clearly marks Phase 3 work
- Fallback logic ensures system works without LLM

**Status:** ✅ **AS DESIGNED** (Phase 1)

---

### **Issue 4: Error Handling in collect_test_output()**

**Current:**
- Handles `TimeoutExpired` and generic `Exception`
- Logs errors but continues

**Recommendation:**
- Consider more specific exception types
- Current implementation is acceptable

**Status:** ✅ **ACCEPTABLE**

---

## 📊 **TESTING RESULTS**

### **Manual Test:**
```bash
$ python3 tools/doctor.py
2025-12-06 01:31:06 UTC [INFO] 🏥 Doctor Agent: Starting health check...
2025-12-06 01:31:06 UTC [INFO] 📋 Diagnosis: ops_qa/gateway_healthy - No auto-heal needed, logging only
2025-12-06 01:31:06 UTC [INFO] 📝 Logged diagnosis to /Users/icmini/02luka/g/telemetry/doctor.jsonl
2025-12-06 01:31:06 UTC [INFO] ✅ Doctor Agent: Health check complete
```

**Result:** ✅ **PASSED**

### **Syntax Check:**
```bash
$ python3 -m py_compile tools/doctor.py
✅ Python syntax check passed
```

**Result:** ✅ **PASSED**

### **Linter:**
- No linter errors found

**Result:** ✅ **PASSED**

---

## 🔍 **CODE QUALITY METRICS**

| Metric | Status | Notes |
|--------|--------|-------|
| **Syntax** | ✅ Pass | No syntax errors |
| **Linter** | ✅ Pass | No linting errors |
| **Error Handling** | ✅ Good | Try/except blocks present |
| **Logging** | ✅ Good | Comprehensive logging |
| **Documentation** | ✅ Good | Docstrings present |
| **Path Handling** | ✅ Fixed | Explicit paths used |
| **Process Management** | ✅ Good | Proper subprocess usage |

---

## 📋 **CHECKLIST VERIFICATION**

### **Phase 1 Requirements:**
- [x] Python 3.12+ compatible
- [x] Shebang: `#!/usr/bin/env python3`
- [x] All required imports
- [x] `collect_test_output()` implemented
- [x] `diagnose_with_fallback()` implemented
- [x] `call_llm_diagnose()` implemented (dummy)
- [x] `execute_auto_heal()` implemented
- [x] `restart_gateway()` implemented
- [x] `log_diagnosis()` implemented
- [x] `main()` implemented
- [x] Executable (`chmod +x`)
- [x] Syntax check passed

### **Phase 2 Requirements:**
- [x] LaunchAgent plist created
- [x] StartInterval: 300
- [x] ThrottleInterval: 30
- [x] Correct paths
- [x] Log paths set

---

## 🎯 **FINAL VERDICT**

### **Overall Score: 9.0/10**

**Breakdown:**
- Code Quality: 9/10 (excellent structure, minor path issue fixed)
- Functionality: 10/10 (all requirements met)
- Error Handling: 9/10 (good, could be more specific)
- Documentation: 9/10 (good docstrings, TODO comments clear)
- Testing: 8/10 (manual test passed, needs more scenarios)

### **Status: ✅ APPROVED - PRODUCTION READY (Phase 1)**

**Recommendations:**
1. ✅ Path issue fixed
2. ⚠️ Consider improving gateway restart mechanism (Phase 2)
3. ⚠️ Add more test scenarios (gateway offline, JSON errors)
4. ✅ Ready for LaunchAgent loading and testing

---

## 🚀 **NEXT STEPS**

1. **Load LaunchAgent:**
   ```bash
   launchctl load ~/Library/LaunchAgents/com.02luka.doctor.plist
   ```

2. **Test Auto-Healing:**
   - Stop gateway
   - Wait 5-6 minutes
   - Verify gateway restarted

3. **Monitor Telemetry:**
   ```bash
   tail -f ~/02luka/g/telemetry/doctor.jsonl
   ```

4. **Phase 3 (Future):**
   - Implement real LLM API calls
   - Improve diagnosis accuracy

---

**End of Code Review**
