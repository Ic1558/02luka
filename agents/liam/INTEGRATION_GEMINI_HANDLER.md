# Integration Guide: Gemini Handler

## File: `bridge/handlers/gemini_handler.py`

This file processes Gemini work orders. Here's where to paste the 3 blocks:

---

## ✅ Integration Point 1: In `handle_wo()` function

**Location:** After line 38 (after preparing payload, before calling `run_gemini_task`)

**Current code:**
```python
def handle_wo(wo: Dict[str, Any]) -> Dict[str, Any]:
    """Normalize a work order payload and execute it via the Gemini connector."""

    task_type = wo.get("task_type", "code_transform")
    input_block = wo.get("input", {}) if isinstance(wo, dict) else {}

    payload = {
        "instructions": input_block.get("instructions", ""),
        "target_files": input_block.get("target_files", []),
        "context": input_block.get("context", {}),
    }

    result = gemini_connector.run_gemini_task(task_type, payload)  # ← BEFORE THIS LINE
```

**Add Block 1 + Block 2 here:**
```python
def handle_wo(wo: Dict[str, Any]) -> Dict[str, Any]:
    """Normalize a work order payload and execute it via the Gemini connector."""

    task_type = wo.get("task_type", "code_transform")
    input_block = wo.get("input", {}) if isinstance(wo, dict) else {}

    payload = {
        "instructions": input_block.get("instructions", ""),
        "target_files": input_block.get("target_files", []),
        "context": input_block.get("context", {}),
    }

    # ✅ PASTE BLOCK 1 HERE
    from agents.liam.mary_router import enforce_overseer
    
    # Convert WO format to task_spec format
    task_spec = {
        "intent": task_type,  # or map task_type to intent
        "target_files": payload.get("target_files", []),
        "command": payload.get("command"),  # if shell command
        "context": payload.get("context", {}),
    }
    
    # Prepare patch_meta or task_meta based on intent
    if task_type in ("code_transform", "refactor", "fix-bug", "add-feature"):
        patch_meta = {
            "changed_files": payload.get("target_files", []),
            "diff_text": payload.get("instructions", ""),
        }
        decision = enforce_overseer(task_spec, patch_meta)
    elif task_type == "run-command":
        task_meta = {
            "command": payload.get("command", ""),
            "task_spec": task_spec,
        }
        decision = enforce_overseer(task_spec, task_meta)
    else:
        decision = {"approval": "Yes"}  # default allow
    
    # ✅ PASTE BLOCK 2 HERE
    from agents.liam.mary_router import apply_decision_gate
    
    gate_result = apply_decision_gate(decision)
    
    if gate_result["status"] == "BLOCKED":
        return {
            "ok": False,
            "engine": "overseer",
            "error": gate_result["reason"],
            "details": gate_result.get("details", []),
        }
    
    if gate_result["status"] == "REVIEW_REQUIRED":
        return {
            "ok": False,
            "engine": "overseer",
            "status": "REVIEW_REQUIRED",
            "reason": gate_result["reason"],
            "details": gate_result.get("details", []),
            "escalate_to": "gm-advisor",
        }
    
    # ✅ If approved, proceed with original call
    result = gemini_connector.run_gemini_task(task_type, payload)
    return {
        "ok": True,
        "engine": "gemini",
        "task_type": task_type,
        "result": result,
    }
```

---

## Alternative: Simpler Integration (Minimal Changes)

If you want minimal changes, just add the decision gate before the `run_gemini_task` call:

```python
# After preparing payload, before run_gemini_task:

from agents.liam.mary_router import enforce_overseer, apply_decision_gate

task_spec = {
    "intent": task_type,
    "target_files": payload.get("target_files", []),
    "context": payload.get("context", {}),
}

if task_type in ("code_transform", "refactor", "fix-bug", "add-feature"):
    patch_meta = {
        "changed_files": payload.get("target_files", []),
        "diff_text": payload.get("instructions", ""),
    }
    decision = enforce_overseer(task_spec, patch_meta)
    gate_result = apply_decision_gate(decision)
    
    if gate_result["status"] in ("BLOCKED", "REVIEW_REQUIRED"):
        return {
            "ok": False,
            "status": gate_result["status"],
            "reason": gate_result["reason"],
            "details": gate_result.get("details", []),
        }

# Continue with original run_gemini_task call
result = gemini_connector.run_gemini_task(task_type, payload)
```

---

## Notes

- This integration is **non-breaking** - if overseer fails, it returns error but doesn't crash
- The WO format is converted to task_spec format on-the-fly
- Block 3 (route_to_cursor/route_to_hybrid_shell) is not needed here since `run_gemini_task` already handles execution
- You may need to map `task_type` values to `intent` values (e.g., "code_transform" → "refactor")
