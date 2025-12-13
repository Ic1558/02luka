# Block 5: WO Processor v5 — Implementation Specification

**Date:** 2025-12-10  
**Feature Slug:** `block5_wo_processor_v5`  
**Status:** 📋 SPEC  
**Priority:** P1 (Critical for Governance v5 Integration)  
**Owner:** GG (System Orchestrator)

---

## 🎯 Objective

Implement WO Processor v5 that:
1. **Lane-Based Routing:** Routes WOs based on Router v5 lane decisions
2. **CLC Bottleneck Reduction:** Only STRICT lane → CLC (70-80% reduction)
3. **Local Execution:** FAST/WARN lanes execute locally (agents + SandboxGuard)
4. **Health Monitoring:** Gateway v3 Router health check mechanism

---

## 📐 Architecture

### Core Components

```
WO Processor v5
├── WO Reader (from bridge/inbox/MAIN/)
├── Router v5 Integration (lane resolution)
├── Lane-Based Router
│   ├── STRICT → CLC Executor
│   ├── FAST/WARN → Local Executor
│   └── BLOCKED → Error Handler
├── Local Execution Engine
│   ├── SandboxGuard v5 Integration
│   └── SIP Engine (CLI mode)
└── Health Check Monitor
    ├── Gateway v3 Router Status
    └── Metrics Collection
```

---

## 🔧 Implementation Details

### Component 1: WO Processor Core

**File:** `bridge/core/wo_processor_v5.py`

**Functions:**
```python
def read_wo_from_main(wo_path: str) -> WorkOrder:
    """Read WO from bridge/inbox/MAIN/"""
    
def process_wo_with_lane_routing(wo: WorkOrder) -> ProcessingResult:
    """
    Process WO with lane-based routing.
    
    Flow:
    1. For each target_path in WO:
       a. Call Router v5: route(trigger, actor, path, op)
       b. Check lane:
          - STRICT → Queue to CLC
          - FAST/WARN → Execute locally
          - BLOCKED → Reject
    2. Route accordingly
    """
    
def route_strict_to_clc(wo: WorkOrder, operations: List[Dict]) -> str:
    """Create WO for CLC and send to bridge/inbox/CLC/"""
    
def execute_local(operations: List[Dict], actor: str, context: Dict) -> ExecutionResult:
    """Execute FAST/WARN lane operations locally"""
```

---

### Component 2: Lane-Based Router

**Logic:**
```python
def route_by_lane(wo: WorkOrder) -> Dict[str, List]:
    """
    Route WO operations by lane.
    
    Returns:
        {
            "strict": [operations for CLC],
            "fast": [operations for local execution],
            "warn": [operations for local execution (if auto-approve)],
            "blocked": [operations to reject]
        }
    """
    strict_ops = []
    fast_ops = []
    warn_ops = []
    blocked_ops = []
    
    for op in wo.operations:
        path = op.get('path')
        routing_decision = router_v5.route(
            trigger=wo.origin.get('trigger', 'background'),
            actor=wo.origin.get('actor', 'CLC'),
            path=path,
            op=op.get('operation', 'write'),
            context={'wo_id': wo.wo_id}
        )
        
        if routing_decision.lane == "STRICT":
            strict_ops.append(op)
        elif routing_decision.lane == "FAST":
            fast_ops.append(op)
        elif routing_decision.lane == "WARN":
            if routing_decision.auto_approve_allowed:
                warn_ops.append(op)
            else:
                # WARN without auto-approve → STRICT
                strict_ops.append(op)
        elif routing_decision.lane == "BLOCKED":
            blocked_ops.append(op)
    
    return {
        "strict": strict_ops,
        "fast": fast_ops,
        "warn": warn_ops,
        "blocked": blocked_ops
    }
```

---

### Component 3: Local Execution Engine

**File:** `bridge/core/local_executor_v5.py`

**Functions:**
```python
def execute_fast_lane(operations: List[Dict], actor: str) -> ExecutionResult:
    """
    Execute FAST lane operations locally.
    
    Flow:
    1. For each operation:
       a. SandboxGuard check
       b. Apply SIP (CLI mode)
       c. Execute write
    2. Log results
    """
    
def execute_warn_lane(operations: List[Dict], actor: str, context: Dict) -> ExecutionResult:
    """
    Execute WARN lane operations locally (if CLS auto-approve allowed).
    
    Flow:
    1. Verify CLS auto-approve conditions
    2. SandboxGuard check
    3. Apply SIP (CLI mode)
    4. Execute write
    5. Log with audit trail
    """
```

---

### Component 4: Health Check Mechanism

**File:** `tools/check_mary_gateway_health.zsh`

**Functions:**
```bash
check_launchagent_status() {
    # Check: launchctl list | grep -i "mary\|gateway"
    # Returns: RUNNING / STOPPED / NOT_FOUND
}

check_process_running() {
    # Check: ps aux | grep -i "gateway_v3_router\|mary.*router"
    # Returns: RUNNING / STOPPED
}

check_log_activity() {
    # Check: tail -n 50 g/telemetry/gateway_v3_router.log
    # Check last activity timestamp
    # Returns: ACTIVE (last 5 min) / STALE / NO_LOG
}

check_inbox_consumption() {
    # Check: Count files in bridge/inbox/MAIN/
    # Check: Last processed timestamp
    # Returns: HEALTHY / BACKLOG / STUCK
}

generate_health_report() {
    # Combine all checks
    # Output: JSON status report
}
```

**Output Format:**
```json
{
  "status": "HEALTHY" | "DEGRADED" | "DOWN",
  "launchagent": "RUNNING" | "STOPPED",
  "process": "RUNNING" | "STOPPED",
  "log_activity": "ACTIVE" | "STALE",
  "inbox_consumption": "HEALTHY" | "BACKLOG",
  "last_activity": "2025-12-10T10:00:00Z",
  "backlog_count": 0,
  "recommendations": []
}
```

---

## 🔒 Critical Rules

### Rule 1: STRICT Lane Only → CLC

**Enforcement:**
- ✅ Only operations with `lane == "STRICT"` go to CLC
- ✅ All other lanes execute locally
- ✅ Log routing decision for audit

**Prohibited:**
- ❌ Sending FAST/WARN lane operations to CLC
- ❌ Bypassing Router v5 lane resolution

---

### Rule 2: No Direct CLC Drops

**Enforcement:**
- ✅ All WOs must go through `bridge/inbox/MAIN/` first
- ✅ WO Processor routes based on lane
- ✅ Only STRICT lane creates WO for CLC

**Exceptions:**
- ⚠️ Emergency manual override (with explicit flag)
- ⚠️ Legacy compatibility (temporary, to be deprecated)

---

### Rule 3: Health Check Integration

**Enforcement:**
- ✅ Health check runs every 5 minutes (or on demand)
- ✅ Unhealthy status → Create alert WO
- ✅ Metrics logged to telemetry

---

## 📊 Integration Points

### Router v5 Integration
```python
from bridge.core.router_v5 import route

routing_decision = route(
    trigger=wo.origin.get('trigger', 'background'),
    actor=wo.origin.get('actor', 'CLC'),
    path=operation['path'],
    op=operation.get('operation', 'write'),
    context={'wo_id': wo.wo_id}
)
```

### SandboxGuard v5 Integration
```python
from bridge.core.sandbox_guard_v5 import check_write_allowed

sandbox_result = check_write_allowed(
    path=operation['path'],
    actor=actor,
    operation='write',
    content=operation.get('content'),
    context={
        'world': 'CLI',
        'zone': routing_decision.zone,
        'lane': routing_decision.lane
    }
)
```

### CLC Executor v5 Integration
```python
# For STRICT lane operations:
# Create WO → Send to bridge/inbox/CLC/
# CLC Executor v5 will process it
```

---

## 🧪 Test Cases

### Test 1: STRICT Lane → CLC
**Input:** WO with LOCKED zone operation (Background world)  
**Expected:** WO created → Sent to `bridge/inbox/CLC/`  
**Verify:** WO appears in CLC inbox, not executed locally

### Test 2: FAST Lane → Local Execution
**Input:** WO with OPEN zone operation (CLI world)  
**Expected:** Executed locally by agent, no WO created  
**Verify:** File written, no WO in CLC inbox

### Test 3: WARN Lane (Auto-approve) → Local Execution
**Input:** WO with LOCKED zone (Mission Scope, CLS auto-approve)  
**Expected:** Executed locally by CLS, no WO created  
**Verify:** File written, audit log created

### Test 4: BLOCKED Lane → Reject
**Input:** WO with DANGER zone operation  
**Expected:** Rejected, moved to `bridge/error/MAIN/`  
**Verify:** Error logged, WO not processed

### Test 5: Health Check
**Input:** Gateway v3 Router running/stopped  
**Expected:** Health report with correct status  
**Verify:** Status matches actual state

---

## 📈 Metrics & Monitoring

### Metrics to Track
- **CLC Workload Reduction:** Count of operations NOT sent to CLC
- **Routing Latency:** Time from WO arrival to routing decision
- **Local Execution Success Rate:** FAST/WARN lane success %
- **Health Check Status:** Gateway v3 Router uptime

### Logging
- All routing decisions logged with:
  - WO ID
  - Lane decision
  - Routing destination
  - Execution result

---

## 🔄 Migration Strategy

### Phase 1: Parallel Operation
- WO Processor v5 runs alongside legacy system
- Route new WOs through v5
- Legacy WOs continue through old path

### Phase 2: Gradual Migration
- Monitor v5 performance
- Migrate legacy WOs to v5
- Deprecate old routing logic

### Phase 3: Full Cutover
- All WOs go through v5
- Legacy system disabled
- Health monitoring active

---

## ✅ Success Criteria

1. ✅ STRICT lane only → CLC (verified by inbox monitoring)
2. ✅ FAST/WARN lanes execute locally (no CLC WO created)
3. ✅ Health check reports accurate status
4. ✅ CLC workload reduced by 70-80%
5. ✅ All routing decisions auditable

---

## 📝 Files to Create

1. `bridge/core/wo_processor_v5.py` (~400 lines)
2. `bridge/core/local_executor_v5.py` (~300 lines)
3. `tools/check_mary_gateway_health.zsh` (~150 lines)
4. `g/config/wo_processor_v5_config.yaml` (config)

---

**Status:** 📋 SPEC Complete — Ready for REVIEW

**Next:** Review → REDESIGN (if needed) → DRYRUN → VERIFY → [ASK BOSS] → IMPLEMENT

