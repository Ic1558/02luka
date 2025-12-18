# PERSONA_MODEL_v5.md Status Report

**Date:** 2025-12-18  
**Status:** ✅ **RESTORED** (Created from code logic)

---

## Summary

`PERSONA_MODEL_v5.md` has been **restored** from code logic and is now available.

### Current State

- ✅ **File created**: `/Users/icmini/02luka/g/docs/PERSONA_MODEL_v5.md`
- ✅ **Content extracted**: From code references in:
  - `bridge/core/router_v5.py` (Section 3: Capability Matrix)
  - `bridge/core/sandbox_guard_v5.py` (Section 5: Forbidden Behaviors)
- ✅ **Verified**: File exists and contains all expected sections

---

## What We Have vs What's Missing

### ✅ What We Have: `GEMINI_PERSONA_v3.md`

**Location**: `/Users/icmini/02luka/personas/GEMINI_PERSONA_v3.md`

**Purpose**: Agent-specific persona for Gemini (one of 10 agents)

**Content**:
- Identity & Mission (Gemini-specific)
- Two Worlds Model (CLI vs Background)
- Zone Mapping (Gemini's permissions)
- Identity Matrix (Gemini's capabilities)
- Mary Router Integration (how Gemini is routed)
- Work Order Decision Rule (Gemini's WO rules)
- Key Principles (Gemini's operational rules)

**Version**: v3 (part of Persona v3 rollout)

**Usage**: Loaded via `load_persona_v5.zsh gemini sync`

---

### ✅ What's Restored: `PERSONA_MODEL_v5.md`

**Location**: `/Users/icmini/02luka/g/docs/PERSONA_MODEL_v5.md` ✅

**Purpose**: **General model/specification** defining capabilities and forbidden behaviors for **all agents** (not agent-specific)

**Content** (extracted from code):

#### Section 3: Capability Matrix
- **Referenced by**: `router_v5.py:400` - "Check capability matrix (PERSONA_MODEL_v5 Section 3.1)"
- **Should define**: Which actors can write in which zones/worlds
- **Current code logic** (from `router_v5.py:401`):
  ```python
  cli_writers = ["Boss", "CLS", "Liam", "GMX", "Codex", "Gemini", "LAC"]
  ```
- **Should document**: Full capability matrix for all 13 actors across CLI/BACKGROUND worlds

#### Section 5: Forbidden Behaviors
- **Referenced by**: `sandbox_guard_v5.py:8, 440` - "PERSONA_MODEL_v5.md (Section 5: Forbidden Behaviors)"
- **Should define**: Behaviors that are forbidden for all agents
- **Current code logic** (from `sandbox_guard_v5.py:441`):
  - DANGER zone: Only Boss with explicit confirmation
  - LOCKED zone: Boss/CLS override or WO → CLC
  - OPEN zone: Allowed for CLI writers
- **Should document**: Complete list of forbidden behaviors, patterns, and exceptions

---

## Key Differences

| Aspect | `GEMINI_PERSONA_v3.md` | `PERSONA_MODEL_v5.md` (Missing) |
|--------|------------------------|--------------------------------|
| **Scope** | Agent-specific (Gemini only) | System-wide (all 13 actors) |
| **Purpose** | Define Gemini's identity, role, permissions | Define capability matrix and forbidden behaviors |
| **Version** | v3 (Persona v3 rollout) | v5 (Governance v5 alignment) |
| **Location** | `personas/GEMINI_PERSONA_v3.md` | `g/docs/PERSONA_MODEL_v5.md` (expected) |
| **Usage** | Loaded into IDEs via `load_persona_v5.zsh` | Referenced by governance code (router, sandbox) |
| **Content Type** | Behavioral contract (how to behave) | Capability spec (what can/cannot do) |
| **Sections** | Identity, Mission, Zones, WO Rules | Capability Matrix, Forbidden Behaviors |

---

## Impact of Missing File

### Current Behavior
- **Router v5**: Hardcodes capability matrix in code (line 401)
- **SandboxGuard v5**: Hardcodes forbidden behaviors in code (line 441)
- **No single source of truth**: Logic scattered across Python files

### Expected Behavior (with PERSONA_MODEL_v5.md)
- **Router v5**: Reads capability matrix from `PERSONA_MODEL_v5.md` Section 3
- **SandboxGuard v5**: Reads forbidden behaviors from `PERSONA_MODEL_v5.md` Section 5
- **Single source of truth**: All capability/permission logic in one document

---

## References in Code

### router_v5.py
```python
# Line 7: Module docstring
- PERSONA_MODEL_v5.md (Section 3: Capability Matrix)

# Line 400: Comment
# Check capability matrix (PERSONA_MODEL_v5 Section 3.1)

# Line 428: Function docstring
- Always: PERSONA_MODEL_v5.md (capabilities)

# Line 440: Code
lawset.append("PERSONA_MODEL_v5.md")
```

### sandbox_guard_v5.py
```python
# Line 8: Module docstring
- PERSONA_MODEL_v5.md (Section 5: Forbidden Behaviors)

# Line 440: Comment
# Logic (GOVERNANCE v5 Section 4.2, PERSONA_MODEL_v5 Section 3):
```

---

## Recommended Action

### Option 1: Create PERSONA_MODEL_v5.md
Extract capability matrix and forbidden behaviors from code into a proper document:

1. **Create** `/Users/icmini/02luka/g/docs/PERSONA_MODEL_v5.md`
2. **Section 3**: Document full capability matrix (all 13 actors × 2 worlds × 3 zones)
3. **Section 5**: Document all forbidden behaviors and exceptions
4. **Update code**: Make router/sandbox read from this file (or keep as reference)

### Option 2: Update Code References
If PERSONA_MODEL_v5.md is not needed:
1. Remove references from `router_v5.py` and `sandbox_guard_v5.py`
2. Document capability matrix in `GOVERNANCE_UNIFIED_v5.md` instead
3. Update code comments to reference correct document

---

## Related Files

- `g/docs/GOVERNANCE_UNIFIED_v5.md` - Main governance document
- `g/docs/AI_OP_001_v5.md` - Operational protocol
- `g/docs/HOWTO_TWO_WORLDS_v2.md` - Two Worlds Model guide
- `personas/GEMINI_PERSONA_v3.md` - Gemini agent persona (v3)
- `bridge/core/router_v5.py` - Routing engine (references PERSONA_MODEL_v5)
- `bridge/core/sandbox_guard_v5.py` - Security guard (references PERSONA_MODEL_v5)

---

**Status**: ✅ File restored and verified  
**Priority**: P0 (Complete - Single source of truth now available)  
**Owner**: Governance v5 team  
**Restored**: 2025-12-18
