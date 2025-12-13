# Governance v5 Integration Wiring Report

**Date:** 2025-12-10  
**Status:** ✅ **WIRED (Integrated)**  
**Purpose:** Document v5 stack integration into Gateway v3 Router

---

## Executive Summary

v5 stack has been successfully integrated into Gateway v3 Router. The system now uses lane-based routing (Router v5) for all Work Orders from `bridge/inbox/MAIN/`.

---

## Integration Flow

```
┌─────────────────────────────────────────────────────────────┐
│  Work Order arrives in bridge/inbox/MAIN/                  │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│  Gateway v3 Router (gateway_v3_router.py)                  │
│  - Detects new WO file                                      │
│  - Calls: process_wo_with_lane_routing(wo_path)             │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│  WO Processor v5 (wo_processor_v5.py)                        │
│  - Reads WO from MAIN inbox                                 │
│  - For each operation:                                      │
│    └─> Calls Router v5: route(trigger, actor, path, op)    │
└──────────────────────┬──────────────────────────────────────┘
                       │
        ┌──────────────┼──────────────┐
        │              │              │
        ▼              ▼              ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│ STRICT Lane  │ │ FAST/WARN    │ │ BLOCKED Lane │
│              │ │ Lane         │ │              │
└──────┬───────┘ └──────┬───────┘ └──────┬───────┘
       │                │                 │
       ▼                ▼                 ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│ CLC Inbox    │ │ Local Exec   │ │ Error Inbox  │
│              │ │ + Sandbox    │ │              │
│ bridge/      │ │ Guard v5     │ │ bridge/      │
│ inbox/CLC/   │ │              │ │ error/MAIN/  │
└──────────────┘ └──────────────┘ └──────────────┘
```

---

## Code Changes

### File: `agents/mary_router/gateway_v3_router.py`

**Changes:**
1. Added v5 stack import:
   ```python
   try:
       from bridge.core.wo_processor_v5 import process_wo_with_lane_routing
       V5_STACK_AVAILABLE = True
   except ImportError:
       V5_STACK_AVAILABLE = False
   ```

2. Modified `process_wo()` method:
   - Tries v5 stack first (if available and enabled)
   - Falls back to legacy routing if v5 fails
   - Logs telemetry for v5 processing

**Integration Point:**
- `process_wo()` → `process_wo_with_lane_routing(wo_path)`

---

## Lane-Based Routing Logic

### STRICT Lane → CLC
- **Destination:** `bridge/inbox/CLC/`
- **Processor:** CLC Executor v5
- **Conditions:** BACKGROUND world OR LOCKED zone (without CLS auto-approve)

### FAST/WARN Lane → Local Execution
- **Destination:** Direct execution (agent + SandboxGuard v5)
- **Processor:** Local execution engine (WO Processor v5)
- **Conditions:** CLI world + OPEN zone (FAST) OR CLI world + LOCKED zone with CLS auto-approve (WARN)

### BLOCKED Lane → Error
- **Destination:** `bridge/error/MAIN/`
- **Processor:** None (rejected)
- **Conditions:** DANGER zone OR invalid operation

---

## Configuration

### File: `g/config/mary_router_gateway_v3.yaml`

**New Option:**
```yaml
use_v5_stack: true  # Enable v5 stack integration
```

**Default:** `true` (v5 stack enabled)

---

## Telemetry

v5 stack processing events are logged to:
- `g/telemetry/gateway_v3_router.log`

**Event Fields:**
- `wo_id`: Work Order ID
- `action`: `process_v5`
- `status`: `ok` or `error`
- `strict_ops`: Number of STRICT lane operations
- `local_ops`: Number of local operations
- `rejected_ops`: Number of rejected operations
- `clc_wo_path`: Path to created CLC WO (if any)

---

## Fallback Behavior

If v5 stack is unavailable or fails:
1. Logs warning
2. Falls back to legacy routing (strict_target → routing_hint → default_target)
3. Maintains backward compatibility

---

## Testing

**Manual Test:**
1. Create WO in `bridge/inbox/MAIN/`
2. Gateway v3 Router processes it
3. Check telemetry log for v5 processing events
4. Verify routing (CLC inbox, local execution, or error)

---

## Status

✅ **WIRED (Integrated)**

- v5 stack integrated into Gateway v3 Router
- Lane-based routing active
- Fallback to legacy routing if needed
- Telemetry logging enabled

---

**Last Updated:** 2025-12-10

