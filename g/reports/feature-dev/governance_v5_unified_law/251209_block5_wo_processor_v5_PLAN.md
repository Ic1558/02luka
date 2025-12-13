# Block 5: WO Processor v5 — Implementation Plan

**Date:** 2025-12-10  
**Feature Slug:** `block5_wo_processor_v5`  
**Status:** 📋 PLAN  
**Priority:** P1 (Critical for Governance v5 Integration)  
**Owner:** GG (System Orchestrator)

---

## 🎯 Executive Summary

**Problem:** CLC is currently a bottleneck because all WOs are routed to CLC without lane-based filtering.

**Solution:** Implement WO Processor v5 that:
- Integrates Router v5 for lane-based routing
- Routes STRICT lane only → CLC
- Executes FAST/WARN lanes locally (agents + SandboxGuard)
- Includes health check mechanism for Gateway v3 Router

**Impact:** Reduces CLC workload by 70-80%, enables true Governance v5 lane-based execution.

---

## 📋 Current State Analysis

### Existing System
- **Gateway v3 Router:** Monitors `bridge/inbox/MAIN/`, routes to agent inboxes
- **CLC Executor:** Processes WOs from `bridge/inbox/CLC/`
- **Mary Dispatcher (Legacy):** Uses `bridge/inbox/ENTRY/`

### Problems
1. ❌ No lane-based routing — all WOs go to CLC
2. ❌ CLC inbox has many pending WOs (bottleneck)
3. ❌ No integration between Router v5 and WO Processor
4. ❌ No health check for Gateway v3 Router

---

## 🎯 Target State

### WO Processor v5 Flow
```
1. WO arrives in bridge/inbox/MAIN/
2. WO Processor reads WO
3. For each target_path:
   a. Call Router v5: route(trigger, actor, path, op)
   b. Check lane:
      - STRICT → Create WO → Send to bridge/inbox/CLC/
      - FAST/WARN → Execute locally (agent + SandboxGuard)
      - BLOCKED → Reject + Log error
4. Health check: Monitor Gateway v3 Router status
```

### Lane-Based Routing Rules
| Lane | Action | Destination | Executor |
|------|--------|-------------|----------|
| STRICT | Create WO → CLC | `bridge/inbox/CLC/` | CLC Executor v5 |
| FAST | Execute locally | Direct execution | Agent (GMX/Codex/Liam/CLS) |
| WARN | Execute locally (if auto-approve) | Direct execution | CLS (with SandboxGuard) |
| BLOCKED | Reject + Log | `bridge/error/MAIN/` | None |

---

## 📝 Tasks Breakdown

### Task 1: WO Processor v5 Core
- [ ] Read WO from `bridge/inbox/MAIN/`
- [ ] Extract trigger, actor, target_paths, operations
- [ ] Integrate Router v5: `router_v5.route()`
- [ ] Implement lane-based routing logic
- [ ] Route STRICT → CLC, FAST/WARN → local execution

### Task 2: Local Execution Engine
- [ ] Execute FAST lane operations (agent + SandboxGuard)
- [ ] Execute WARN lane operations (CLS auto-approve check)
- [ ] Integrate SandboxGuard v5 for pre-write checks
- [ ] Apply SIP for local writes

### Task 3: CLC Routing (STRICT Lane Only)
- [ ] Create WO for STRICT lane operations
- [ ] Validate WO schema
- [ ] Send to `bridge/inbox/CLC/`
- [ ] Log routing decision

### Task 4: Health Check Mechanism
- [ ] LaunchAgent status check
- [ ] Process running check
- [ ] Log activity check (last 5 minutes)
- [ ] Inbox consumption check
- [ ] Health report generation

### Task 5: Integration & Testing
- [ ] Integration with Router v5
- [ ] Integration with SandboxGuard v5
- [ ] Integration with CLC Executor v5
- [ ] Test lane-based routing
- [ ] Test health check

---

## 🧪 Test Strategy

### Unit Tests
- Router v5 integration
- Lane-based routing logic
- Health check functions

### Integration Tests
- End-to-end: MAIN inbox → Router → Agent/CLC
- STRICT lane → CLC routing
- FAST/WARN lane → local execution

### Performance Tests
- CLC workload reduction (measure before/after)
- Routing latency
- Health check overhead

---

## 📊 Success Criteria

1. ✅ STRICT lane only → CLC (no FAST/WARN in CLC inbox)
2. ✅ FAST/WARN lanes execute locally (no WO created)
3. ✅ Health check reports Gateway v3 Router status
4. ✅ CLC workload reduced by 70-80%
5. ✅ All routing decisions logged and auditable

---

## 🔗 Dependencies

- ✅ Block 1: Router v5 Core (Complete)
- ✅ Block 2: SandboxGuard v5 (Complete)
- ✅ Block 3: CLC Enforcement Engine v5 (Complete)
- ⏳ Block 4: Multi-File SIP Engine (Pending)
- ⏳ Block 5: WO Processor v5 (This Plan)

---

## 📅 Timeline

- **Phase 1:** WO Processor Core + Router Integration (2-3 hours)
- **Phase 2:** Local Execution Engine (1-2 hours)
- **Phase 3:** Health Check Mechanism (1 hour)
- **Phase 4:** Integration & Testing (1-2 hours)

**Total:** ~5-8 hours

---

**Status:** 📋 PLAN Complete — Ready for SPEC

**Next:** Create SPEC.md with detailed implementation

