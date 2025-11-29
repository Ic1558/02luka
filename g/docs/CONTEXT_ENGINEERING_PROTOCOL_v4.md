# Context Engineering Protocol v4.0

## 1. Overview
This protocol defines how agents, humans, and tools interact with the 02luka codebase.
It is fully aligned with **AI/OP-001 v4 (Lego Edition)**.

## 2. Zone Definitions

### 2.1 Locked Zones (LZ)
**Writers:** CLC, LPE (Emergency)
**Paths:**
- `core/**`
- `CLC/**`
- `launchd/**`
- `bridge/inbox/**`
- `bridge/outbox/**`
- `bridge/handlers/**`
- `bridge/core/**`
- `bridge/templates/**`
- `bridge/production/**`

### 2.2 Open Zones (OZ)
**Writers:** Gemini, LAC, Codex, CLS, GG, GC
**Paths:**
- `apps/**`
- `tools/**`
- `agents/**`
- `tests/**`
- `docs/**` (non-governance)
- `bridge/docs/**`
- `bridge/samples/**`

## 3. Capability Matrix

| Agent | Role | Locked Zone | Open Zone |
| :--- | :--- | :---: | :---: |
| **CLC** | Primary System Writer | ✅ Write | ⚠️ Rare |
| **LPE** | Emergency Patcher | ⚠️ Boss Only | ❌ |
| **CLS** | System Orchestrator | ❌ | ✅ Write |
| **Gemini** | Operational Worker | ❌ | ✅ Write |
| **LAC** | Auto-Coder | ❌ | ✅ Write |
| **Codex** | IDE Assistant | ❌ | ✅ Write (Diff) |
| **GG** | Governance Gate | ❌ | ⚠️ Propose |
| **GC** | Governance Consultant | ❌ | ⚠️ Propose |

## 4. Conflict Resolution

### 4.1 First-Writer-Locks
- Once a writer lane (e.g., Gemini) is active for a task, no other agent may write to the same files until the task is complete.

### 4.2 Drift-to-Locked
- If a task starts in an Open Zone but discovers a need to modify a Locked Zone file:
  1. Stop writing.
  2. Escalate to CLC via Work Order.
  3. CLC takes over the Locked Zone portion.

### 4.3 Post-Write Review
- All Open Zone writes must be committed with a descriptive message.
- If a violation is detected (e.g., breaking the build), CLC/LPE may be invoked to revert or fix.

## 5. Operational Rules
- **mktemp → mv:** All writes must use atomic move patterns.
- **Audit:** All writes to Locked Zones require full SHA256 audit trails. Open Zones require at least a git commit log.
- **Routing:** Mary/GG determines the correct writer lane based on the task scope.

---
**Version:** v4.0
**Status:** Active
**SOT:** `g/docs/CONTEXT_ENGINEERING_PROTOCOL_v4.md`
