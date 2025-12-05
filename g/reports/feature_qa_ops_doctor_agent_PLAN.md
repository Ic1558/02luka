# Feature: QA & Ops Diagnostics Doctor Agent

**Feature ID:** `qa_ops_doctor_agent`  
**Priority:** HIGH  
**Status:** PLANNING  
**Date:** 2025-12-05

---

## 🎯 **PROBLEM STATEMENT**

### **Current Situation:**

1. **Gateway Health Monitoring:** No automated health checks for `gateway.py` (port 5001)
2. **Manual Diagnostics:** When gateway fails, requires manual investigation
3. **No Auto-Healing:** Gateway downtime requires manual restart
4. **QA Diagnostics:** Test failures require manual analysis to determine root cause

### **User Need:**

- **Auto-monitor** gateway health (every X minutes)
- **Auto-diagnose** test failures using LLM-based analysis
- **Auto-heal** common issues (e.g., restart gateway if offline)
- **Integrate** with existing Mary/LAC infrastructure (not Opal App)

---

## ✅ **SOLUTION OVERVIEW**

### **Architecture:**

```
┌─────────────────────────────────────────┐
│  LaunchAgent (com.02luka.doctor)        │
│  └─ Runs every 5 minutes                │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  tools/doctor.py                         │
│  ├─ Collect test_output (curl/ping)     │
│  ├─ Call LLM (Gemini/GG) with prompt    │
│  ├─ Parse JSON diagnosis                │
│  └─ Execute auto-heal actions          │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  LLM (Gemini/GG)                         │
│  └─ QA & Ops Diagnostics Prompt        │
│     (classify lane, root_cause, action)  │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  Auto-Heal Actions                       │
│  ├─ Restart gateway (if offline)        │
│  ├─ Log to telemetry                    │
│  └─ Notify via Telegram (if critical)   │
└─────────────────────────────────────────┘
```

### **Key Design Decisions:**

1. **Local Agent (NOT Opal):** Runs on `icmini` machine, not in Opal App flow
2. **LLM-Based Diagnosis:** Uses Gemini/GG API with structured prompt
3. **Auto-Healing:** Restarts gateway automatically if diagnosed as offline
4. **Integration:** Works alongside Mary/LAC, not replacing them
5. **Telemetry:** Logs all diagnoses to `g/telemetry/doctor.jsonl`

---

## 📋 **COMPONENT SPECIFICATIONS**

### **1. tools/doctor.py**

**Purpose:** Main diagnostic agent script

**Inputs:**
- Test outputs from `curl` commands
- Context string (e.g., "/api/wo_status health-check")

**Outputs:**
- JSON diagnosis: `{ lane, root_cause, evidence, severity, next_actions }`
- Auto-heal actions (if applicable)
- Telemetry logs

**Dependencies:**
- Python 3.12+
- `requests` (for LLM API calls)
- `subprocess` (for curl/restart commands)
- Gemini API key or GG API access

**Key Functions:**
```python
def collect_test_output() -> str:
    """Run health checks and collect output"""
    # curl http://localhost:5001/ping
    # curl http://localhost:5001/api/wo_status?limit=3
    # Return combined output

def diagnose_with_fallback(test_output: str, context: str) -> dict:
    """
    Diagnose with LLM, fallback to heuristics if LLM fails.
    
    Returns diagnosis dict with lane, root_cause, severity, evidence, next_actions.
    """
    try:
        diag = call_llm_diagnose(test_output, context)
        return diag
    except Exception as e:
        # Fallback: Heuristic-based diagnosis if LLM unavailable
        logger.warning(f"⚠️ LLM diagnosis failed: {e}, using fallback heuristics")
        
        if "Failed to connect to localhost" in test_output or \
           "Connection refused" in test_output or \
           "Gateway not running" in test_output:
            return {
                "lane": "ops_qa",
                "root_cause": "gateway_offline",
                "severity": "high",
                "evidence": ["connection failure detected (LLM unavailable, using fallback)"],
                "next_actions": [
                    "restart gateway.py",
                    "check LaunchAgent if repeated failures"
                ]
            }
        elif "invalid json" in test_output.lower() or \
             "missing required keys" in test_output.lower():
            return {
                "lane": "qa",
                "root_cause": "api_contract_mismatch",
                "severity": "medium",
                "evidence": ["JSON contract issue detected (LLM unavailable)"],
                "next_actions": [
                    "inspect gateway /api/wo_status implementation",
                    "check response format"
                ]
            }
        else:
            return {
                "lane": "qa_rnd",
                "root_cause": "diagnostics_degraded_llm_unavailable",
                "severity": "medium",
                "evidence": [f"LLM call failed: {e}, no clear pattern in test_output"],
                "next_actions": [
                    "check LLM API status",
                    "review doctor logs",
                    "verify gateway manually"
                ]
            }

def call_llm_diagnose(test_output: str, context: str) -> dict:
    """Call LLM with QA diagnostics prompt"""
    # Use Gemini/GG API
    # Return parsed JSON diagnosis
    # Raises Exception if LLM call fails

def execute_auto_heal(diagnosis: dict) -> None:
    """Execute auto-healing actions based on diagnosis"""
    lane = diagnosis.get("lane")
    root_cause = diagnosis.get("root_cause")
    
    if lane == "ops_qa" and root_cause == "gateway_offline":
        restart_gateway()
    else:
        log_diagnosis(diagnosis)

def restart_gateway() -> None:
    """Restart gateway.py process"""
    # pkill -f gateway.py
    # nohup python gateway.py > /tmp/gateway.log 2>&1 &
```

---

### **2. QA & Ops Diagnostics Prompt**

**Location:** Embedded in `tools/doctor.py` as system prompt

**Format:** Strict JSON output

**Rules:**
1. **Connection failures** → `lane: "ops_qa"`, `root_cause: "gateway_offline"` → Auto-restart
2. **JSON contract mismatches** → `lane: "qa"`, `root_cause: "api_contract_mismatch"` → Log only
3. **Test script issues** → `lane: "qa_rnd"`, `root_cause: "test_script_or_edge_case"` → Log only
4. **Python exceptions** → `lane: "dev_fix"`, `root_cause: "runtime_exception"` → Log + notify

**Output Schema:**
```json
{
  "lane": "ops_qa | qa | qa_rnd | dev_fix",
  "root_cause": "<short_label>",
  "evidence": ["...quotes from test_output..."],
  "severity": "low | medium | high | critical",
  "next_actions": ["step 1 ...", "step 2 ..."]
}
```

---

### **3. LaunchAgent Configuration**

**File:** `~/Library/LaunchAgents/com.02luka.doctor.plist`

**Configuration:**
- **Label:** `com.02luka.doctor`
- **Program:** `/Users/icmini/02luka/tools/doctor.py`
- **RunAtLoad:** `true`
- **KeepAlive:** `false` (runs on schedule, not continuously)
- **StartInterval:** `300` (5 minutes)
- **ThrottleInterval:** `30` (prevent feedback loops)
- **StandardOutPath:** `~/02luka/logs/doctor.stdout.log`
- **StandardErrorPath:** `~/02luka/logs/doctor.stderr.log`

---

### **4. Telemetry Logging**

**Location:** `g/telemetry/doctor.jsonl`

**Format:** JSON Lines

**Fields:**
```json
{
  "timestamp": "2025-12-05T17:46:02Z",
  "context": "/api/wo_status health-check",
  "diagnosis": {
    "lane": "ops_qa",
    "root_cause": "gateway_offline",
    "severity": "high",
    "evidence": ["..."]
  },
  "action_taken": "restart_gateway",
  "action_result": "success | failed",
  "gateway_pid": 12345
}
```

---

## 🗺️ **LANE → OWNERSHIP MAPPING**

### **Diagnostic Lane Ownership (02luka System)**

| Lane | Primary Owner | Responsibilities | Auto-Action |
|------|---------------|------------------|-------------|
| **ops_qa** | Doctor Agent + Infra Ops | Gateway health, connectivity, LaunchAgent status | ✅ Auto-restart gateway if offline |
| **qa** | QA Lane / LAC Test Tools | API contract mismatches, response format issues | ⚠️ Log only, requires manual test adjustment |
| **qa_rnd** | R&D / LAC Experiment | Edge cases, flaky tests, test script issues | ⚠️ Log only, requires investigation |
| **dev_fix** | Dev / CLC | Runtime exceptions, code bugs, requires patch | ❌ Log + notify, requires WO creation |

**Usage:**
- When reading `g/telemetry/doctor.jsonl`, use this mapping to route issues to correct team
- `ops_qa` issues → Doctor Agent handles automatically
- Other lanes → Create WO or assign to appropriate team

---

## 🔧 **IMPLEMENTATION TASKS**

### **Phase 1: Core Doctor Script (HIGH Priority)**

- [ ] **Task 1.1:** Create `tools/doctor.py` skeleton
  - Collect test output (ping + /api/wo_status)
  - Call LLM API (Gemini/GG)
  - Parse JSON diagnosis
  - **Deliverable:** `tools/doctor.py` (runnable)

- [ ] **Task 1.2:** Embed QA diagnostics prompt
  - Escape quotes/newlines for Python string
  - Format as system prompt
  - **Deliverable:** Prompt embedded in `doctor.py`

- [ ] **Task 1.3:** Implement auto-heal logic
  - Detect `gateway_offline` root cause
  - Restart gateway process
  - Verify restart success
  - **Deliverable:** Auto-heal working

- [ ] **Task 1.4:** Add telemetry logging
  - Write to `g/telemetry/doctor.jsonl`
  - Include diagnosis + action taken
  - **Deliverable:** Logs written correctly

---

### **Phase 2: LaunchAgent Integration (MEDIUM Priority)**

- [ ] **Task 2.1:** Create LaunchAgent plist
  - Follow existing pattern (Mary/LAC)
  - Set StartInterval to 5 minutes
  - **Deliverable:** `com.02luka.doctor.plist`

- [ ] **Task 2.2:** Install LaunchAgent
  - Copy to `~/Library/LaunchAgents/`
  - Load with `launchctl load`
  - **Deliverable:** Agent running on schedule

- [ ] **Task 2.3:** Test LaunchAgent
  - Verify runs every 5 minutes
  - Check logs for errors
  - **Deliverable:** Agent stable

---

### **Phase 3: LLM Integration (HIGH Priority)**

- [ ] **Task 3.1:** Choose LLM provider
  - Option A: Gemini API (recommended)
  - Option B: GG API (if available)
  - **Decision:** Based on API key availability

- [ ] **Task 3.2:** Implement LLM client
  - API key from `.env.local`
  - Error handling for API failures
  - **Deliverable:** LLM calls working

- [ ] **Task 3.3:** Test prompt accuracy
  - Simulate gateway offline
  - Simulate JSON contract mismatch
  - Verify correct lane classification
  - **Deliverable:** Prompt working correctly

---

### **Phase 4: Notification Integration (LOW Priority)**

- [ ] **Task 4.1:** Integrate with notify_worker
  - Send Telegram alert for critical issues
  - Use existing `bridge/inbox/NOTIFY/` flow
  - **Deliverable:** Notifications sent

- [ ] **Task 4.2:** Add notification rules
  - Only notify for `severity: "critical"`
  - Throttle notifications (max 1/hour)
  - **Deliverable:** Smart notifications

---

## 🧪 **TEST STRATEGY**

### **Test Cases:**

1. **Gateway Offline:**
   - Stop gateway
   - Run `doctor.py`
   - Verify: `lane: "ops_qa"`, `root_cause: "gateway_offline"`
   - Verify: Gateway restarted automatically

2. **Gateway Online:**
   - Gateway running normally
   - Run `doctor.py`
   - Verify: No action taken, diagnosis logged

3. **JSON Contract Mismatch:**
   - Modify gateway to return invalid JSON
   - Run `doctor.py`
   - Verify: `lane: "qa"`, `root_cause: "api_contract_mismatch"`
   - Verify: No auto-heal (log only)

4. **Python Exception:**
   - Inject error in gateway.py
   - Run `doctor.py`
   - Verify: `lane: "dev_fix"`, `root_cause: "runtime_exception"`
   - Verify: Logged + notified (if critical)

5. **LaunchAgent Schedule:**
   - Install LaunchAgent
   - Wait 5 minutes
   - Verify: Agent runs automatically
   - Check logs for errors

---

## 📊 **SUCCESS METRICS**

1. **Auto-Healing Rate:**
   - Gateway offline → Restarted within 5 minutes: **>95%**

2. **Diagnosis Accuracy:**
   - Correct lane classification: **>90%**
   - Correct root cause identification: **>85%**

3. **Uptime Improvement:**
   - Gateway downtime reduced by: **>50%**

4. **False Positives:**
   - Incorrect auto-restarts: **<5%**

---

## 🔗 **INTEGRATION POINTS**

### **Existing Infrastructure:**

1. **Mary (COO):**
   - Doctor runs alongside Mary (no conflict)
   - Mary handles WO routing, Doctor handles health

2. **LAC Manager:**
   - Doctor runs alongside LAC (no conflict)
   - LAC handles task execution, Doctor handles diagnostics

3. **notify_worker:**
   - Doctor can send notifications via `/api/notify`
   - Uses existing notification infrastructure

4. **Gateway:**
   - Doctor monitors gateway health
   - Auto-restarts if offline

---

## ⚠️ **RISKS & MITIGATIONS**

### **Risk 1: LLM API Failures**
- **Impact:** Doctor cannot diagnose
- **Mitigation:** Fallback to simple heuristics (ping check)

### **Risk 2: False Positives (Restart Healthy Gateway)**
- **Impact:** Service disruption
- **Mitigation:** Require 2 consecutive failures before restart

### **Risk 3: LaunchAgent Feedback Loop**
- **Impact:** Doctor restarts gateway → Doctor detects restart → Loop
- **Mitigation:** ThrottleInterval = 30 seconds, cooldown period

### **Risk 4: API Key Exposure**
- **Impact:** Security breach
- **Mitigation:** Store in `.env.local` (gitignored), never commit

---

## 📝 **CLARIFYING QUESTIONS**

1. **LLM Provider:**
   - Prefer Gemini API or GG API?
   - Do we have API keys available?

2. **Restart Strategy:**
   - Restart immediately on first failure?
   - Or require 2 consecutive failures?

3. **Notification Threshold:**
   - Notify for all `severity: "high"`?
   - Or only `severity: "critical"`?

4. **Integration with Mary:**
   - Should Doctor report to Mary?
   - Or operate independently?

---

## 🚀 **NEXT STEPS**

1. **Answer clarifying questions** (above)
2. **Implement Phase 1** (Core Doctor Script)
3. **Test with real gateway** (offline/online scenarios)
4. **Deploy LaunchAgent** (Phase 2)
5. **Monitor telemetry** (verify accuracy)

---

**End of Feature Plan**
