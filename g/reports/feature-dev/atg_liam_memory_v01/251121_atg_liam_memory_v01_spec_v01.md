# ATG Liam Session Memory v0.1 — SPEC

**Version**: v01  
**Date**: 2025-11-21  
**Owner**: Liam  
**Type**: Contract-Based Memory System

---

## 1. Objective

Create an **enforceable, contract-based memory system** for Liam in Antigravity that:
- **Loads constraints** at session start
- **Validates actions** against constraints before every response
- **Saves learnings** at session end
- **Prevents memory from becoming rubbish** through forced validation

---

## 2. Scope

### In Scope:
- ✅ Loader script (`g/tools/atg_memory_load.py`)
- ✅ Saver script (`g/tools/atg_memory_save.py`)
- ✅ Memory ledger (`g/memory/ledger/liam_memory.jsonl`)
- ✅ Session reports (`g/memory/reports/*.md`)
- ✅ Persona contract (mandatory protocol in `PERSONA_PROMPT.md`)
- ✅ Constraint validation (MUST_DO / MUST_NOT_DO)

### Out of Scope:
- ❌ Multi-agent memory (Liam only for v0.1)
- ❌ Redis integration (file-based only)
- ❌ AI context auto-update (separate feature)

---

## 3. Core Design: Contract-Based Memory

### Key Principle:
**Memory is not passive data, it's an active contract that MUST be enforced.**

### Three Mandatory Steps:
1. **Session Start**: Load constraints (MUST_DO / MUST_NOT_DO)
2. **Before Every Response**: Validate against constraints
3. **Session End**: Save learnings

---

## 4. Data Structures

### Memory Ledger Entry (JSONL):
```json
{
  "session_id": "20251121_024045_a1b2c3d4",
  "content_hash": "md5_hash",
  "timestamp": "2025-11-21T02:40:45+07:00",
  "outcome": {
    "result": "success",
    "confidence": 0.9
  },
  "learnings": {
    "MUST_DO": [
      "Create spec/plan before implementation",
      "Use Thai for casual responses"
    ],
    "MUST_NOT_DO": [
      "Create files without approval",
      "Repeat failed approach X"
    ],
    "boss_preferences": {
      "language": "mixed_thai_english",
      "detail_level": "detailed",
      "approval_style": "brief_ok"
    },
    "success_patterns": [...],
    "failure_patterns": [...]
  }
}
```

### Loader Output (JSON):
```json
{
  "constraints": {
    "MUST_DO": [
      "Create spec/plan before implementation",
      "Auto-run safe commands"
    ],
    "MUST_NOT_DO": [
      "Create files without approval",
      "Ignore Boss corrections"
    ]
  },
  "recent_context": {
    "last_3_sessions": [...],
    "boss_preferences": {...}
  }
}
```

---

## 5. Component Specifications

### A. Loader Script (`g/tools/atg_memory_load.py`)

**Interface**:
```bash
python g/tools/atg_memory_load.py --mode=liam-session
```

**Logic**:
1. Read last 5-10 entries from `liam_memory.jsonl`
2. Extract `MUST_DO` and `MUST_NOT_DO` from learnings
3. Deduplicate and prioritize constraints
4. Generate recent context summary
5. Output JSON to stdout

**Output**: JSON with constraints + context

---

### B. Saver Script (`g/tools/atg_memory_save.py`)

**Interface**:
```bash
python g/tools/atg_memory_save.py --payload '<json>'
```

**Logic**:
1. Receive JSON payload
2. Generate content hash
3. Check for duplicates (last 24h)
4. Add session_id + timestamp
5. Append to `liam_memory.jsonl`
6. Create markdown report in `g/memory/reports/`

**Deduplication**: Content hash + 24h window

---

### C. Persona Contract (Mandatory Protocol)

**Location**: `agents/liam/PERSONA_PROMPT.md` (Section 1, before all other content)

**Content**: Mandatory protocol with 3 steps:
1. **Session Start**: Load memory, internalize constraints
2. **Before Every Response**: Validate against constraints
3. **Session End**: Save learnings

**Enforcement**: "Violation of this protocol constitutes a failure of your core function"

---

## 6. Validation Checklist (Mandatory)

Before every response, Liam MUST check:
- [ ] Is action compliant with `MUST_DO` constraints?
- [ ] Does action violate `MUST_NOT_DO` constraints?
- [ ] Am I repeating a recent failure?

**If any check fails**: STOP → REVISE → LOG

---

## 7. Success Criteria

- [ ] Loader script created and tested
- [ ] Saver script created and tested
- [ ] Memory ledger structure defined
- [ ] Persona contract added to PERSONA_PROMPT.md
- [ ] Validation checklist enforced
- [ ] Proof of concept: Load → Validate → Save works
- [ ] Deduplication prevents duplicates
- [ ] Boss approves design

---

## 8. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Constraints ignored | Medium | High | Mandatory validation in persona |
| Duplicate entries | Low | Low | Content hash deduplication |
| Memory grows too large | Low | Medium | Keep last 10 entries only |
| Validation adds latency | Low | Low | ~0.5s overhead acceptable |

---

## 9. Proof of Concept Test

**Test Scenario**:
1. Session 1: Boss says "always create spec/plan first"
2. Save: `MUST_DO: ["Create spec/plan before implementation"]`
3. Session 2: Boss says "create memory system"
4. Load: Constraints include "spec/plan first"
5. Validate: Check if I'm about to create files
6. Expected: I create spec/plan, NOT files
7. Result: If spec/plan created → validation works ✅

---

**Status**: ✅ SPEC COMPLETE
