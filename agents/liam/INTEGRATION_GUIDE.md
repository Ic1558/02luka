# Mary Router Integration Guide

## Overview

This guide shows how to wire GMX → Mary Router → Overseer → (Cursor / Hybrid Shell).

## Quick Integration (3 Steps - Final Version)

### ✅ Block 1 — GMX → Mary Router

**ใช้ตอน GMX bridge หรือ Liam ได้ task_spec + payload แล้ว:**

```python
from agents.liam.mary_router import enforce_overseer

decision = enforce_overseer(task_spec, payload)
```

### ✅ Block 2 — Decision Gate

**วางก่อนจะไปเรียก Cursor หรือ Hybrid Shell:**

```python
from agents.liam.mary_router import apply_decision_gate

gate_result = apply_decision_gate(decision)

if gate_result["status"] == "BLOCKED":
    return {
        "status": "BLOCKED",
        "reason": gate_result["reason"],
        "details": gate_result.get("details", []),
    }

if gate_result["status"] == "REVIEW_REQUIRED":
    return {
        "status": "REVIEW_REQUIRED",
        "reason": gate_result["reason"],
        "details": gate_result.get("details", []),
        "escalate_to": "gm-advisor",
    }

# If passed → proceed to Cursor or HybridShell
```

### ✅ Block 3 — Route to Execution

**ใช้หลังจาก gate บอกว่า APPROVED แล้ว:**

```python
from agents.liam.mary_router import route_to_cursor, route_to_hybrid_shell

# For patches
if task_spec["intent"] in ("refactor", "fix-bug", "add-feature", "generate-file"):
    result = route_to_cursor(task_spec, patch_meta)
    # result["status"] == "PATCH_READY"

# For shell commands
if task_spec["intent"] == "run-command":
    result = route_to_hybrid_shell(task_meta)
    # result["status"] == "COMMAND_READY"
```

## Complete Flow Diagram

```
GMX → generate task_spec
    ↓
Mary Router (enforce_overseer)
    ↓
Overseer (decide_for_patch / decide_for_shell)
    ↓
Decision Gate (apply_decision_gate)
    ├─ approval: Yes → Cursor gen patch / HybridShell.run()
    ├─ approval: Review → Gemini Advisor
    └─ approval: No → Block
```

## Example: Complete Integration

See `agents/liam/mary_router_integration_example.py` for a complete working example.

## Status Codes

- `APPROVED`: Overseer approved, proceed with execution
- `BLOCKED`: Overseer blocked, do not execute
- `REVIEW_REQUIRED`: Requires GM/Gemini advisor review before execution
- `PATCH_READY`: Patch generated and ready (from Cursor)
- `COMMAND_READY`: Command ready for execution (from Hybrid Shell)

## Notes

- All functions return dicts for easy integration
- `trigger_details` included in decisions for debugging
- No breaking changes to existing code
- Overseer + PolicyLoader already working

---

## 📍 Specific Integration Examples

### Gemini Handler Integration

See `INTEGRATION_GEMINI_HANDLER.md` for step-by-step integration in `bridge/handlers/gemini_handler.py`

### General Paste Locations

See `PASTE_LOCATIONS.md` for general guidance on finding integration points

---

## ✅ Summary

**Status:** ✅ Ready to use

- ✅ All 3 blocks tested and working
- ✅ Overseer + GMX policy fully functional
- ✅ Integration examples provided
- ✅ Non-breaking - safe to add to existing code

**Next:** Identify your GMX bridge/entrypoint file and paste the blocks according to the patterns above.
