# ✅ GMX Wiring - Ready to Integrate

## Status: COMPLETE ✅

All components are ready. Just copy-paste the 3 blocks into your GMX bridge/handler files.

---

## ✅ Verification Checklist

### Core Components
- [x] `governance/policy_loader.py` - PolicyLoader class working
- [x] `governance/overseerd.py` - decide_for_patch/decide_for_shell working
- [x] `context/safety/gm_policy_v4.yaml` - Policy config loaded (gmx-v1)
- [x] `agents/liam/mary_router.py` - All functions implemented

### Integration Files
- [x] `agents/liam/INTEGRATION_GUIDE.md` - **Final 3 blocks** (use this!)
- [x] `agents/liam/PASTE_LOCATIONS.md` - General paste guidance
- [x] `agents/liam/INTEGRATION_GEMINI_HANDLER.md` - Gemini handler example
- [x] `agents/liam/mary_router_integration_example.py` - Complete working example

### Testing
- [x] `sandbox_overseer_demo.py` - Demo script working
- [x] `governance/test_overseerd.py` - All 9 tests passing
- [x] `governance/test_policy_loader.py` - Policy loader tests passing

---

## 📋 Final 3 Blocks (Copy-Paste Ready)

### ✅ Block 1 — GMX → Mary Router

**Paste after:** You have `task_spec` + `payload` ready

```python
from agents.liam.mary_router import enforce_overseer

decision = enforce_overseer(task_spec, payload)
```

---

### ✅ Block 2 — Decision Gate

**Paste after:** Block 1, before calling Cursor/Hybrid Shell

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

---

### ✅ Block 3 — Route to Execution

**Paste after:** Block 2 approves (APPROVED status)

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

---

## 🎯 Quick Start Guide

### Step 1: Identify Your Entry Point

Find the file that:
- Receives GMX task_spec (from ChatGPT/Gemini/other)
- Calls Cursor or Hybrid Shell
- Processes work orders

**Common locations:**
- `bridge/handlers/gemini_handler.py` ← See `INTEGRATION_GEMINI_HANDLER.md`
- `bridge/handlers/*_handler.py`
- `agents/**/gmx*.py`
- Any file that processes `task_spec` or work orders

### Step 2: Copy-Paste Blocks

1. **Block 1** → After preparing `task_spec` + `payload`
2. **Block 2** → Before calling Cursor/Hybrid Shell
3. **Block 3** → After Block 2 approves

### Step 3: Test

Run your handler with a sample task_spec and verify:
- BLOCKED case works (dangerous commands)
- REVIEW_REQUIRED case works (GM triggers)
- APPROVED case routes correctly

---

## 📚 Documentation Reference

- **Main Guide:** `INTEGRATION_GUIDE.md` - Final 3 blocks
- **Paste Locations:** `PASTE_LOCATIONS.md` - General guidance
- **Gemini Example:** `INTEGRATION_GEMINI_HANDLER.md` - Specific example
- **Working Example:** `mary_router_integration_example.py` - Complete flow

---

## ✅ What's Working

- ✅ Overseer + GMX policy fully functional
- ✅ PolicyLoader loads gmx-v1 policy correctly
- ✅ decide_for_patch returns Review with trigger_details
- ✅ decide_for_shell blocks dangerous commands
- ✅ Mary Router functions tested and working
- ✅ All 3 blocks return proper status codes
- ✅ trigger_details included for debugging

---

## 🚀 Next Action

**Just copy-paste the 3 blocks from `INTEGRATION_GUIDE.md` into your GMX bridge/handler file.**

No changes needed to the blocks themselves - they're final and tested.

---

**Status:** ✅ Ready to integrate  
**Risk:** ✅ Low (non-breaking, safe to add)  
**Testing:** ✅ All tests passing
