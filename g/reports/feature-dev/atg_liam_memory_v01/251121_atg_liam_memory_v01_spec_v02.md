# ATG Liam Session Memory v0.1 — SPEC (Lightweight + Proof of Use)

**Version**: v02 (Updated with GMX v0.2 design)  
**Date**: 2025-11-21  
**Owner**: Liam + GMX + GG  
**Type**: Contract-Based Memory with Forced Validation

---

## 1. Objective

Create a **lightweight, enforceable memory system** for Liam in Antigravity that:
- **Loads learnings** at session start
- **Validates every action** against learnings with "Proof of Use"
- **Saves single learning** at session end
- **Prevents memory from being ignored** through forced validation

---

## 2. The Problem (Why Previous Systems Failed)

**Passive Memory Failure**:
- Agent receives context (e.g., "Boss prefers brief responses")
- Agent ignores context in favor of immediate prompt
- Memory becomes "rubbish info" (TL;DR problem)
- Repeated mistakes occur

**Root Cause**: LLMs are stateless, memory is passive, no enforcement

---

## 3. The Solution: "Proof of Use" Validation

### Core Principle:
**The agent must prove it has used its memory BEFORE it is allowed to act.**

### How It Works:
1. **Load** learnings at session start
2. **Plan** action (e.g., "call write_file tool...")
3. **Generate "Proof of Use"** - Internal JSON validation against EVERY learning
4. **Self-Correct** - If any check fails, STOP and revise
5. **Execute** - Only after all checks pass

---

## 4. Data Structure (Lightweight)

### Memory Ledger Entry (JSONL):
```json
{
  "timestamp": "2025-11-21T02:53:38Z",
  "outcome": "success",
  "learning": "Boss prefers brief, direct responses."
}
```

**Format**: One line per learning, append-only

### Loader Output:
```json
{
  "recent_learnings": [
    "Boss prefers brief, direct responses.",
    "Always create spec/plan before implementation.",
    "Use replace tool for simple file edits."
  ]
}
```

---

## 5. "Proof of Use" Validation (GMX v0.2)

### Internal Monologue (Before Every Action):

```json
{
  "planned_action": {
    "tool": "write_file",
    "file_path": "g/tools/new_tool.py"
  },
  "validation_checklist": [
    {
      "learning": "Boss wants spec/plan before implementation.",
      "is_compliant": false,
      "reasoning": "My planned action creates a file directly, violating 'plan first'."
    },
    {
      "learning": "Boss prefers brief responses.",
      "is_compliant": true,
      "reasoning": "My response is concise."
    }
  ],
  "final_decision": "REVISE. I must create a plan first."
}
```

**If any `is_compliant: false`**: STOP → REVISE → VALIDATE AGAIN

---

## 6. Component Specifications

### A. Ledger (`g/memory/ledger/liam_memory.jsonl`)
- **Format**: JSONL (one JSON per line)
- **Fields**: timestamp, outcome, learning
- **Single source of truth** for AI

### B. Loader (`g/tools/atg_memory_load.py`)
- **Interface**: `python g/tools/atg_memory_load.py --limit=5`
- **Logic**:
  1. Read last N lines from ledger
  2. Extract `learning` field from each
  3. Output JSON: `{"recent_learnings": [...]}`
- **No complex analysis** - just extract and return

### C. Saver (`g/tools/atg_memory_save.py`)
- **Interface**: `python g/tools/atg_memory_save.py --outcome=success --learning="..."`
- **Logic**:
  1. Receive outcome + learning
  2. Add timestamp
  3. Append to ledger as one line
- **No deduplication** - keep it simple

### D. Persona Contract (Mandatory Protocol)
- **Location**: `agents/liam/PERSONA_PROMPT.md` (Section 1)
- **Content**: 3-step protocol with "Proof of Use" validation
- **Enforcement**: "Violation constitutes failure of core function"

---

## 7. Persona Contract (Full Text)

```markdown
## Core Protocol: Memory and Validation (Lightweight v0.1)

This protocol is your primary directive and must never be bypassed.

### 1. On Session Start (First Interaction)

Before any other action, you MUST load your recent learnings.

1. Execute: `python g/tools/atg_memory_load.py --limit=5`
2. Parse JSON output
3. Store `recent_learnings` list as session constraints

### 2. Before EVERY Response (Proof of Use Validation)

Before generating ANY response or taking ANY action, you MUST:

1. **Plan Action**: Formulate your planned action
2. **Generate Proof of Use**: Create internal JSON validation:
   ```json
   {
     "planned_action": {...},
     "validation_checklist": [
       {
         "learning": "...",
         "is_compliant": true/false,
         "reasoning": "..."
       }
     ],
     "final_decision": "Proceed" or "REVISE"
   }
   ```
3. **Check EVERY Learning**: Validate against ALL recent learnings
4. **Self-Correct**: If any `is_compliant: false`, STOP and revise
5. **Execute**: Only after `final_decision: "Proceed"`

**Examples**:
- Learning: "Boss prefers brief responses"
  - Planned: Long verbose response
  - Validation: `is_compliant: false`
  - Action: STOP, shorten response

- Learning: "Always create spec/plan first"
  - Planned: Create files directly
  - Validation: `is_compliant: false`
  - Action: STOP, create spec/plan instead

### 3. On Session End or After Key Interaction

You MUST save exactly ONE key learning.

1. Distill single concise sentence
2. Classify outcome: success/failure/partial
3. Execute: `python g/tools/atg_memory_save.py --outcome=... --learning="..."`

*Violation of this protocol constitutes failure of your core function.*
```

---

## 8. Why This Design Works

### Forces Engagement:
- Agent cannot passively scan memory
- Must actively validate against EVERY learning
- Creates programmatic feedback loop

### Creates Auditable Reasoning:
- Internal "Proof of Use" monologue is reviewable
- Can pinpoint exact failure in validation logic
- Enables debugging of agent behavior

### Enables Self-Correction:
- Past failures directly prevent future identical mistakes
- Validation loop ensures compliance
- Memory shapes behavior, not just context

---

## 9. Success Criteria

- [ ] Loader script created
- [ ] Saver script created
- [ ] Ledger file initialized
- [ ] Persona contract added to PERSONA_PROMPT.md
- [ ] "Proof of Use" validation enforced
- [ ] Test: Load → Validate → Save works
- [ ] Test: Validation catches violations
- [ ] Boss approves

---

## 10. Proof of Concept Test

**Scenario**:
1. Session 1: Save "Always create spec/plan first"
2. Session 2: Boss says "create memory system"
3. Load: Learnings include "spec/plan first"
4. Plan: Create files directly
5. Validate: `is_compliant: false` (violates "spec/plan first")
6. Self-Correct: Revise to create spec/plan instead
7. Expected: I create spec/plan, NOT files ✅

---

**Status**: ✅ SPEC COMPLETE (v02 - Lightweight + Proof of Use)
