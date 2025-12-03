# Mary Router Integration - Paste Locations Guide

## ✅ Final 3 Blocks (Ready to Copy-Paste)

### Block 1 — GMX → Mary Router

```python
from agents.liam.mary_router import enforce_overseer

decision = enforce_overseer(task_spec, payload)
```

**Paste Location:** หลังจากได้ `task_spec` และ `payload` จาก GMX bridge

---

### Block 2 — Decision Gate

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

**Paste Location:** ก่อนเรียก Cursor generate patch หรือ Hybrid Shell run command

---

### Block 3 — Route to Execution

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

**Paste Location:** หลังจาก gate บอกว่า APPROVED แล้ว

---

## 🔍 Finding Your Integration Points

### Step 1: Identify GMX Bridge Entrypoint

ค้นหาไฟล์ที่:
- รับ task_spec จาก GMX/ChatGPT/Gemini
- มี function ที่ process task_spec
- เรียก Cursor หรือ Hybrid Shell

**Possible locations:**
- `bridge/inbox/**/*.py` - Work order inbox handlers
- `bridge/outbox/**/*.py` - Work order outbox handlers
- `agents/**/gmx*.py` - GMX agent files
- `tools/**/*bridge*.py` - Bridge tools
- `tools/**/*worker*.py` - Worker scripts

### Step 2: Identify Cursor/Hybrid Shell Call Sites

ค้นหาจุดที่:
- เรียก Cursor API หรือ generate patch
- เรียก Hybrid Shell หรือ execute command
- มี `if intent == "..."` หรือ `if task_spec["intent"]`

### Step 3: Paste Blocks in Order

1. **Block 1** → หลังได้ task_spec + payload
2. **Block 2** → ก่อนเรียก Cursor/Hybrid Shell
3. **Block 3** → หลัง gate approve

---

## 📝 Example Integration Pattern

```python
def process_gmx_task(task_spec: dict):
    # ... existing code to prepare payload ...
    
    # ✅ PASTE BLOCK 1 HERE
    from agents.liam.mary_router import enforce_overseer
    decision = enforce_overseer(task_spec, payload)
    
    # ✅ PASTE BLOCK 2 HERE
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
    
    # ✅ PASTE BLOCK 3 HERE (if approved)
    from agents.liam.mary_router import route_to_cursor, route_to_hybrid_shell
    
    if task_spec["intent"] in ("refactor", "fix-bug", "add-feature", "generate-file"):
        result = route_to_cursor(task_spec, patch_meta)
        return result
    
    if task_spec["intent"] == "run-command":
        result = route_to_hybrid_shell(task_meta)
        return result
```

---

## ✅ Verification Checklist

- [ ] Block 1 pasted after receiving task_spec + payload
- [ ] Block 2 pasted before calling Cursor/Hybrid Shell
- [ ] Block 3 pasted after gate approval
- [ ] All imports added at top of file
- [ ] Test with sample task_spec
- [ ] Verify BLOCKED case works
- [ ] Verify REVIEW_REQUIRED case works
- [ ] Verify APPROVED case routes correctly

---

## 🚀 Next Steps

1. **Identify your GMX bridge file** - Tell me the file path and I'll create exact paste locations
2. **Or use the pattern above** - Find similar code structure and paste accordingly
3. **Test incrementally** - Start with Block 1, test, then add Block 2, test, then Block 3

**All functions are safe to add** - They don't break existing code, just add new safety checks.
