# Liam Agent - Code Audit Report

**Date**: 2025-11-20
**Scope**: `agents/liam/*.py`
**Auditor**: Antigravity

## Executive Summary
The audit reveals a **CRITICAL** gap in AP/IO v3.1 compliance. While the routing logic exists, there is **zero integration with the AP/IO Ledger**. Liam is defined as the "Document Owner" of this protocol, yet his own code fails to implement it. Additionally, some default behaviors in the router are "fail-open" (defaulting to "Yes"), which is a security risk.

## Findings

### 1. Critical: Missing AP/IO v3.1 Ledger Integration
- **File**: `agents/liam/mary_router.py`
- **Severity**: **High**
- **Issue**: The code processes tasks and makes decisions but **does not log** these events to `g/ledger/ap_io_v31.jsonl`.
- **Violation**: Violates the core requirement that "All significant actions are logged."
- **Missing Fields**: No handling of `ledger_id`, `parent_id`, `correlation_id`, or `execution_duration_ms`.

### 2. Security: Unsafe Default "Fail-Open"
- **File**: `agents/liam/mary_router.py`
- **Location**: `apply_decision_gate` (Line 49)
- **Severity**: **Medium**
- **Issue**: `approval = decision.get("approval", "Yes")`
- **Risk**: If the Overseer returns a malformed response or fails, the router defaults to **allowing** the action.
- **Fix**: Change default to `"No"` or `"BLOCKED"`.

### 3. Code Quality: Missing Input Validation
- **File**: `agents/liam/mary_router.py`
- **Location**: `enforce_overseer`
- **Severity**: **Low**
- **Issue**: No validation that `task_spec` contains required fields (e.g., `intent`) before processing.
- **Risk**: Potential `AttributeError` or silent failures with malformed inputs.

### 4. Implementation: Placeholder Logic
- **File**: `agents/liam/mary_router.py`
- **Location**: `route_to_cursor`, `route_to_hybrid_shell`
- **Severity**: **Low**
- **Issue**: Functions return `None` for `patch` and `result`.
- **Note**: This is acceptable for a router, but needs to be connected to actual execution engines eventually.

## Proposed Fixes (Do Not Apply Yet)

### Fix 1: Integrate AP/IO Logger
Modify `mary_router.py` to import and use the ledger writer.

```python
# Proposed Import
from tools.ap_io_v31.writer import write_ledger_entry

# Proposed Usage in enforce_overseer
def enforce_overseer(task_spec: dict, payload: dict) -> dict:
    # ... logic ...
    write_ledger_entry(
        event="overseer_check",
        ledger_id=new_id(),
        parent_id=task_spec.get("parent_id"),
        data={"decision": decision}
    )
    return decision
```

### Fix 2: Secure Defaults
Change the default approval logic:

```python
# Current
approval = decision.get("approval", "Yes")

# Proposed
approval = decision.get("approval", "BLOCKED")
```

### Fix 3: Add Validation
Add Pydantic models or explicit checks at the entry points.

## Next Steps
1.  **Approve this report.**
2.  **Authorize fixes**: specifically the AP/IO integration and security defaults.
3.  **Create Protocol**: `docs/AP_IO_V31_PROTOCOL.md` must be created before we can fully implement the logger (as noted in `task.md`).
