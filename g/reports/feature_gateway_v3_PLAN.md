# Feature Development Plan: WO Gateway v3 (Phase 0)

**Feature:** WO Gateway v3 - Central Inbox + Mary Router  
**Status:** 📋 **PLAN - Ready for Implementation**  
**Created:** 2025-12-06  
**Author:** GG/CLS  
**Priority:** P1  
**Phase:** 0 (Minimal Viable Gateway)

---

## 🎯 **EXECUTIVE SUMMARY**

### **Problem Statement**

Current system has **distributed inboxes** - each agent (CLC, LIAM, LAC, etc.) has its own inbox directory. This creates:
- ❌ Multiple entry points (hard to track)
- ❌ Inconsistent routing logic
- ❌ No central visibility
- ❌ Producers (GG, Opal, CLI) must know target agent

### **Solution: Central Gateway Pattern**

**Gateway v3** introduces:
- ✅ **Single entry point:** `bridge/inbox/MAIN/` (all WOs go here)
- ✅ **Central router:** Mary Router worker routes to agent inboxes
- ✅ **Unified tracking:** All WO lifecycle in one place
- ✅ **Simplified producers:** Write to MAIN only, router handles distribution

### **Phase 0 Scope (Minimal Viable)**

**Focus:** Prove the concept with minimal implementation
- ✅ Central inbox: `bridge/inbox/MAIN/`
- ✅ Mary Router worker (Python, long-running)
- ✅ Routing: MAIN → CLC only (via `strict_target: CLC`)
- ❌ **Not in scope:** Opal integration, UI changes, other lanes (LIAM, QA, etc.)

---

## 📋 **CURRENT STATE ANALYSIS**

### **Existing System**

**Mary Dispatcher (Current):**
- **Location:** `tools/watchers/mary_dispatcher.zsh`
- **Entry Point:** `bridge/inbox/ENTRY/`
- **Routing:** Based on `strict_target`, `routing_hint`, `wo_routing_rules.yaml`
- **Targets:** CLC, LPE, shell, LAC, CLS, Andy
- **Behavior:** Single-pass script (runs via LaunchAgent interval)

**Current Flow:**
```
Producer → bridge/inbox/ENTRY/ → mary_dispatcher.zsh → bridge/inbox/{AGENT}/
```

**Issues:**
- Multiple entry points (ENTRY, direct agent inboxes)
- No central tracking
- Producers must know routing logic

### **Target State (Gateway v3)**

**New Flow:**
```
Producer → bridge/inbox/MAIN/ → mary_router (gateway_v3) → bridge/inbox/{AGENT}/
```

**Benefits:**
- Single entry point
- Central routing logic
- Unified telemetry
- Easier migration path

---

## 🎯 **FEATURE OBJECTIVES**

### **Primary Goals**

1. **Central Inbox:** All WOs enter via `bridge/inbox/MAIN/`
2. **Mary Router Worker:** Long-running Python worker routes WOs
3. **Backward Compatibility:** Existing WOs still work
4. **Telemetry:** Track all routing decisions

### **Success Criteria**

- ✅ `bridge/inbox/MAIN/` exists and is used
- ✅ Mary Router worker routes MAIN → CLC correctly
- ✅ LaunchAgent runs worker continuously
- ✅ WO test from MAIN reaches CLC inbox
- ✅ Telemetry logs routing decisions
- ✅ No breaking changes to existing system

---

## 🔧 **TECHNICAL SPECIFICATION**

### **1. Directory Structure**

```
bridge/
├── inbox/
│   ├── MAIN/          # ← NEW: Central inbox
│   ├── CLC/          # ← Existing (destination)
│   ├── LIAM/         # ← Existing (not in Phase 0)
│   ├── LAC/          # ← Existing (not in Phase 0)
│   └── ENTRY/        # ← Existing (keep for backward compat)
├── processed/
│   └── MAIN/         # ← NEW: Processed WOs from MAIN
└── error/
    └── MAIN/         # ← NEW: Error WOs from MAIN
```

### **2. WO Schema v3**

**Base Schema (Backward Compatible):**
```yaml
wo_id: string              # Required
title: string              # Required
strict_target: string      # Optional: "CLC", "LIAM", "LAC", etc.
routing_hint: string       # Optional: "dev_oss", "qa", etc.
priority: string           # Optional: "P1", "P2", "P3", "low", "normal", "high"
status: string             # Optional: "pending", "processing", "completed"
objective: string          # Optional: Multi-line description
scope: object              # Optional: include/exclude paths
constraints: array         # Optional: List of constraints
tasks: array               # Optional: Task breakdown
acceptance_criteria: array # Optional: Success criteria
outputs: array             # Optional: Expected outputs
notes: string              # Optional: Additional notes
```

**New Fields (v3):**
```yaml
entry_channel: string      # Optional: "MAIN", "ENTRY", "direct" (for tracking)
created_by: string         # Optional: "GG", "Opal", "CLI", "GMX", etc.
source: string             # Optional: Source system identifier
created_at: string         # Optional: ISO timestamp
```

**Backward Compatibility:**
- ✅ WOs without new fields still route correctly
- ✅ Existing WO format (v2) fully supported
- ✅ `strict_target` takes highest priority (same as current)

### **3. Mary Router Worker**

**Location:** `agents/mary_router/gateway_v3_router.py`

**Architecture:**
- Long-running Python process
- Watches `bridge/inbox/MAIN/` directory
- Processes WOs in order (FIFO)
- Routes based on `strict_target` → `routing_hint` → default
- Moves processed WOs to `bridge/processed/MAIN/`
- Moves error WOs to `bridge/error/MAIN/`

**Routing Logic (Phase 0):**
```python
def route_wo(wo_data: dict) -> str:
    # Priority 1: strict_target
    if wo_data.get("strict_target"):
        target = wo_data["strict_target"].upper()
        if target == "CLC":
            return "CLC"
        # Other targets not in Phase 0 scope
    
    # Priority 2: routing_hint (not used in Phase 0)
    # Priority 3: default
    return "CLC"  # Phase 0 default
```

**Error Handling:**
- Invalid YAML → Move to `bridge/error/MAIN/` + log
- Missing required fields → Move to `bridge/error/MAIN/` + log
- Routing failure → Move to `bridge/error/MAIN/` + log
- All errors logged to `g/telemetry/gateway_v3_router.log`

### **4. Configuration File**

**Location:** `g/config/mary_router_gateway_v3.yaml`

**Structure:**
```yaml
version: "3.0"
phase: 0

routing:
  default_target: "CLC"
  supported_targets:
    - "CLC"
  # Phase 0: Only CLC supported

telemetry:
  log_file: "g/telemetry/gateway_v3_router.log"
  log_level: "INFO"

directories:
  inbox: "bridge/inbox/MAIN"
  processed: "bridge/processed/MAIN"
  error: "bridge/error/MAIN"
```

### **5. LaunchAgent Configuration**

**Location:** `~/Library/LaunchAgents/com.02luka.mary-gateway-v3.plist`

**Configuration:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.02luka.mary-gateway-v3</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/env</string>
        <string>python3</string>
        <string>/Users/icmini/02luka/agents/mary_router/gateway_v3_router.py</string>
    </array>
    <key>WorkingDirectory</key>
    <string>/Users/icmini/02luka</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>ThrottleInterval</key>
    <integer>30</integer>
    <key>StandardOutPath</key>
    <string>/Users/icmini/02luka/logs/mary-gateway-v3.stdout.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/icmini/02luka/logs/mary-gateway-v3.stderr.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>LUKA_SOT</key>
        <string>/Users/icmini/02luka</string>
        <key>PYTHONPATH</key>
        <string>/Users/icmini/02luka</string>
    </dict>
</dict>
</plist>
```

---

## 📝 **TASK BREAKDOWN**

### **Task 1: Directory Structure & Configuration**

**ID:** `T1-structure`  
**Estimated Time:** 15 minutes  
**Priority:** P1

**Steps:**
1. Create `bridge/inbox/MAIN/` directory
2. Create `bridge/processed/MAIN/` directory
3. Create `bridge/error/MAIN/` directory
4. Create `agents/mary_router/` directory
5. Create `g/config/mary_router_gateway_v3.yaml` with Phase 0 config

**Acceptance:**
- ✅ All directories exist
- ✅ Config file has valid YAML structure
- ✅ Config includes Phase 0 settings

---

### **Task 2: WO Schema Documentation**

**ID:** `T2-schema`  
**Estimated Time:** 30 minutes  
**Priority:** P1

**Steps:**
1. Document WO Schema v3 (superset of v2)
2. Document new fields: `entry_channel`, `created_by`, `source`, `created_at`
3. Document backward compatibility rules
4. Create `g/reports/gateway_v3_wo_schema_20251206.md`

**Output:**
- Schema documentation with examples
- Backward compatibility matrix
- Migration guide (for future phases)

**Acceptance:**
- ✅ Schema doc exists and is complete
- ✅ Backward compatibility clearly documented
- ✅ Examples provided for all field types

---

### **Task 3: Mary Router Worker Implementation**

**ID:** `T3-worker`  
**Estimated Time:** 2-3 hours  
**Priority:** P1

**Steps:**
1. Create `agents/mary_router/__init__.py`
2. Create `agents/mary_router/gateway_v3_router.py`:
   - Directory watcher for `bridge/inbox/MAIN/`
   - YAML loader with error handling
   - Routing logic (strict_target → default)
   - File mover (inbox → processed/error)
   - Telemetry logger
   - Main loop with sleep interval
3. Add error handling for:
   - Invalid YAML
   - Missing required fields
   - File system errors
   - Routing failures

**Code Structure:**
```python
# agents/mary_router/gateway_v3_router.py
import yaml
import logging
from pathlib import Path
from typing import Dict, Any, Optional
import time

class GatewayV3Router:
    def __init__(self, config_path: str = "g/config/mary_router_gateway_v3.yaml"):
        # Load config, setup logging, initialize paths
    
    def load_wo(self, wo_path: Path) -> Optional[Dict[str, Any]]:
        # Load YAML with error handling
    
    def route_wo(self, wo_data: Dict[str, Any]) -> str:
        # Phase 0: strict_target → CLC default
    
    def process_wo(self, wo_path: Path) -> bool:
        # Load → Route → Move → Log
    
    def run(self):
        # Main loop: watch directory, process WOs, sleep

if __name__ == "__main__":
    router = GatewayV3Router()
    router.run()
```

**Acceptance:**
- ✅ Worker runs without errors
- ✅ Routes MAIN → CLC correctly
- ✅ Handles errors gracefully
- ✅ Logs all actions

---

### **Task 4: LaunchAgent Setup**

**ID:** `T4-launchagent`  
**Estimated Time:** 20 minutes  
**Priority:** P1

**Steps:**
1. Create `~/Library/LaunchAgents/com.02luka.mary-gateway-v3.plist`
2. Configure: RunAtLoad, KeepAlive, ThrottleInterval
3. Set log paths: `logs/mary-gateway-v3.{stdout,stderr}.log`
4. Set environment variables: LUKA_SOT, PYTHONPATH
5. Test: `launchctl load`, `launchctl unload`, check logs

**Acceptance:**
- ✅ LaunchAgent loads without errors
- ✅ Worker starts on load
- ✅ Logs appear in expected locations
- ✅ Worker processes WOs correctly

---

### **Task 5: Validation & Testing**

**ID:** `T5-validation`  
**Estimated Time:** 30 minutes  
**Priority:** P1

**Steps:**
1. Create test WO: `bridge/inbox/MAIN/WO-TEST-GATEWAY-V3.yaml`
   ```yaml
   wo_id: "WO-TEST-GATEWAY-V3"
   title: "Gateway v3 Phase 0 Test"
   strict_target: "CLC"
   priority: "P2"
   status: "pending"
   objective: "Test MAIN → CLC routing"
   ```
2. Wait for Mary Router to process (or trigger manual run)
3. Verify WO moved to `bridge/inbox/CLC/WO-TEST-GATEWAY-V3.yaml`
4. Verify WO moved from MAIN (check `bridge/processed/MAIN/`)
5. Check telemetry logs for routing decision
6. Create validation report: `g/reports/gateway_v3_phase0_validation_20251206.md`

**Test Cases:**
- ✅ Test 1: Valid WO with `strict_target: CLC` → Routes to CLC
- ✅ Test 2: Valid WO without `strict_target` → Routes to CLC (default)
- ✅ Test 3: Invalid YAML → Moves to error/
- ✅ Test 4: Missing required fields → Moves to error/
- ✅ Test 5: Worker restart → Continues processing

**Acceptance:**
- ✅ All test cases pass
- ✅ Validation report created
- ✅ Telemetry logs show routing decisions
- ✅ No errors in worker logs

---

## 🧪 **TEST STRATEGY**

### **Unit Tests**

**Scope:** Router logic, YAML parsing, error handling

**Test Cases:**
1. `route_wo()` with `strict_target: CLC` → Returns "CLC"
2. `route_wo()` without `strict_target` → Returns "CLC" (default)
3. `load_wo()` with valid YAML → Returns dict
4. `load_wo()` with invalid YAML → Returns None, logs error
5. `process_wo()` with valid WO → Moves to CLC, logs success

**Location:** `agents/mary_router/test_gateway_v3_router.py` (optional, not in Phase 0)

---

### **Integration Tests**

**Scope:** End-to-end MAIN → CLC flow

**Test Procedure:**
1. Create test WO in `bridge/inbox/MAIN/`
2. Wait for worker to process (or trigger manually)
3. Verify WO appears in `bridge/inbox/CLC/`
4. Verify WO removed from `bridge/inbox/MAIN/`
5. Verify telemetry log entry

**Test Files:**
- `bridge/inbox/MAIN/WO-TEST-GATEWAY-V3.yaml`
- Expected: `bridge/inbox/CLC/WO-TEST-GATEWAY-V3.yaml`

---

### **Manual Testing Checklist**

- [ ] Worker starts on LaunchAgent load
- [ ] Worker processes WO from MAIN
- [ ] WO appears in CLC inbox
- [ ] WO removed from MAIN inbox
- [ ] Telemetry logs show routing decision
- [ ] Error WO (invalid YAML) moves to error/
- [ ] Worker continues after error
- [ ] Worker restarts correctly

---

## 📊 **ACCEPTANCE CRITERIA**

### **Functional Requirements**

- ✅ `bridge/inbox/MAIN/` directory exists and is used
- ✅ Mary Router worker routes MAIN → CLC correctly
- ✅ LaunchAgent runs worker continuously
- ✅ WO test from MAIN reaches CLC inbox
- ✅ Telemetry logs routing decisions
- ✅ Error handling works (invalid YAML → error/)

### **Non-Functional Requirements**

- ✅ Backward compatible (existing WOs still work)
- ✅ No breaking changes to existing system
- ✅ Worker runs as long-running process
- ✅ Error recovery (worker continues after errors)
- ✅ Logging sufficient for debugging

### **Documentation Requirements**

- ✅ WO Schema v3 documented
- ✅ Validation report created
- ✅ Implementation notes in code comments

---

## 🔄 **MIGRATION PATH**

### **Phase 0 (Current)**
- ✅ MAIN inbox exists
- ✅ Mary Router routes MAIN → CLC
- ✅ Existing system unchanged

### **Phase 1 (Future)**
- Migrate producers to MAIN:
  - GG → Write to MAIN
  - Opal → Write to MAIN
  - CLI tools → Write to MAIN
  - GMX/Codex → Write to MAIN

### **Phase 2 (Future)**
- Add routing for other lanes:
  - MAIN → LIAM
  - MAIN → QA
  - MAIN → DEV_LAC_MANAGER

### **Phase 3 (Future)**
- Deprecate ENTRY inbox
- Full migration to MAIN
- Remove old routing logic

---

## ⚠️ **CONSTRAINTS & ASSUMPTIONS**

### **Constraints**

1. **Phase 0 Scope:**
   - ✅ Only MAIN → CLC routing
   - ❌ No other lanes (LIAM, QA, etc.)
   - ❌ No Opal integration
   - ❌ No UI changes

2. **Backward Compatibility:**
   - ✅ Existing WOs must still work
   - ✅ ENTRY inbox remains functional
   - ✅ Existing LaunchAgents unchanged

3. **No Breaking Changes:**
   - ✅ Don't modify existing Mary dispatcher
   - ✅ Don't remove existing inboxes
   - ✅ Don't change WO schema (only extend)

### **Assumptions**

1. Python 3.8+ available
2. PyYAML available (already used in system)
3. File system permissions allow directory creation
4. LaunchAgent permissions configured

---

## 📦 **DELIVERABLES**

### **Code**
- ✅ `agents/mary_router/gateway_v3_router.py` - Main worker
- ✅ `agents/mary_router/__init__.py` - Package init
- ✅ `g/config/mary_router_gateway_v3.yaml` - Configuration

### **Infrastructure**
- ✅ `bridge/inbox/MAIN/` - Central inbox
- ✅ `bridge/processed/MAIN/` - Processed WOs
- ✅ `bridge/error/MAIN/` - Error WOs
- ✅ `~/Library/LaunchAgents/com.02luka.mary-gateway-v3.plist` - LaunchAgent

### **Documentation**
- ✅ `g/reports/gateway_v3_wo_schema_20251206.md` - Schema documentation
- ✅ `g/reports/gateway_v3_phase0_validation_20251206.md` - Validation report

---

## 🚀 **IMPLEMENTATION PLAN**

### **Step 1: Setup (T1)**
- Create directories
- Create config file
- **Time:** 15 minutes

### **Step 2: Documentation (T2)**
- Document schema
- Document compatibility
- **Time:** 30 minutes

### **Step 3: Implementation (T3)**
- Implement worker
- Add error handling
- **Time:** 2-3 hours

### **Step 4: LaunchAgent (T4)**
- Create plist
- Test loading
- **Time:** 20 minutes

### **Step 5: Validation (T5)**
- Create test WO
- Run end-to-end test
- Create report
- **Time:** 30 minutes

**Total Estimated Time:** 3.5-4.5 hours

---

## 📋 **RISK ASSESSMENT**

| Risk | Severity | Mitigation |
|------|----------|------------|
| Worker crashes | 🟡 Medium | KeepAlive in LaunchAgent, error handling |
| YAML parsing errors | 🟢 Low | Error handling, move to error/ |
| File system permissions | 🟡 Medium | Check permissions, create directories |
| Performance (many WOs) | 🟢 Low | Phase 0 has low volume, optimize later |
| Breaking existing system | 🔴 High | Don't modify existing code, parallel system |

---

## ✅ **FINAL CHECKLIST**

### **Pre-Implementation**
- [x] Plan reviewed and approved
- [x] Scope clearly defined
- [x] Constraints documented
- [x] Test strategy defined

### **Implementation**
- [ ] T1: Directories and config created
- [ ] T2: Schema documentation complete
- [ ] T3: Worker implemented and tested
- [ ] T4: LaunchAgent configured and tested
- [ ] T5: Validation complete

### **Post-Implementation**
- [ ] All acceptance criteria met
- [ ] Documentation complete
- [ ] Validation report created
- [ ] Ready for Phase 1 planning

---

## 📝 **NOTES**

- **Phase 0 Focus:** Prove concept with minimal implementation
- **Future Phases:** Will add more lanes, migrate producers, integrate Opal
- **Backward Compatibility:** Critical - existing system must continue working
- **Telemetry:** Important for debugging and monitoring

---

**Status:** 📋 **PLAN COMPLETE - READY FOR IMPLEMENTATION**  
**Next Step:** Create WO for CLC to implement Phase 0
